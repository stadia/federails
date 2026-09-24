require 'linzer'
require 'linzer/faraday'
require 'linzer/rack'

Linzer::Message.register_adapter ActionDispatch::Request, Linzer::Message::Adapter::Rack::Request

module Fediverse
  module Signature
    class Rfc9421
      class << self
        def sign(sender:, request:)
          request.headers['Content-Digest'] = digest(request.body) if request.body
          Linzer.sign!(
            request,
            key:        linzer_private_key(sender),
            components: components(request),
            params:     {
              created: Time.now.to_i,
              alg:     'rsa-v1_5-sha256',
            }
          )
          request
        end

        MAX_AGE = 900 # seconds, same as Linzer's default
        CLOCK_SKEW_MARGIN = 3600 # seconds a signature may be dated in the future

        # Verifies each signature label in turn and returns the sender of the first valid one.
        #
        # @return [Fedipub::Actor, false] the signer, or false if the request has no RFC9421 signature
        # @raise [Fediverse::Signature::BadSignature] when no signature label is valid
        def verify!(request:) # rubocop:todo Metrics/AbcSize
          # Do we have a signature to verify?
          return false if !request.headers.key?('Signature-Input') || !request.headers.key?('Signature')

          message = Linzer::Message.new(request)
          headers = { 'signature-input' => message.header('signature-input'), 'signature' => message.header('signature') }
          errors = signature_labels(headers).map do |label|
            return verify_label!(request, message, headers, label)
          rescue Fediverse::Signature::BadSignature, Linzer::Error => e
            "#{label}: #{e.message}"
          end
          raise Fediverse::Signature::BadSignature, errors.join('; ')
        rescue Linzer::Error => e
          raise Fediverse::Signature::BadSignature, e.message
        end

        private

        def signature_labels(headers)
          Linzer::HTTP::StructuredField.parse_dictionary(headers['signature-input'], field_name: 'signature-input').keys
        end

        def verify_label!(request, message, headers, label)
          signature = Linzer::Signature.build(headers.dup, label: label)
          check_covered_components!(request, signature)
          check_created!(signature)

          sender = Fediverse::Signature.find_sender(signature.parameters['keyid'])
          verify_with_key_refresh!(sender, message, signature)
          sender
        end

        def verify_with_key_refresh!(sender, message, signature)
          Linzer.verify(linzer_public_key(sender), message, signature)
        rescue Linzer::VerifyError
          # Only a cryptographic mismatch is worth retrying with a refreshed key
          raise unless Fediverse::Signature.refresh_stale_sender!(sender)

          Linzer.verify(linzer_public_key(sender), message, signature)
        end

        # Linzer only verifies what the signer chose to cover
        def check_covered_components!(request, signature)
          missing = %w[@method @target-uri]
          missing += ['content-digest'] if Fediverse::Signature.body?(request)
          missing -= signature.components
          raise Fediverse::Signature::BadSignature, "Signature does not cover #{missing.join(', ')}" if missing.any?
        end

        def check_created!(signature)
          created = signature.created
          raise Fediverse::Signature::BadSignature, 'Signature is missing the created parameter' unless created

          age = Time.now.to_i - created
          raise Fediverse::Signature::BadSignature, "Signature created #{age}s ago" if age > MAX_AGE
          raise Fediverse::Signature::BadSignature, 'Signature created in the future' if age < -CLOCK_SKEW_MARGIN
          raise Fediverse::Signature::BadSignature, 'Signature has expired' if signature.expired?
        end

        # Converts key to right structure for Linzer to use
        def linzer_private_key(sender)
          private_key = OpenSSL::PKey::RSA.new sender.private_key, Rails.application.credentials.secret_key_base
          Linzer.new_rsa_v1_5_sha256_key(private_key.to_pem, sender.key_id)
        end

        def linzer_public_key(sender)
          public_key = OpenSSL::PKey::RSA.new(sender.public_key)
          Linzer.new_rsa_v1_5_sha256_key(public_key.to_pem, sender.key_id)
        rescue OpenSSL::PKey::PKeyError => e
          raise Fediverse::Signature::BadSignature, "Invalid public key for #{sender.federated_url}: #{e.message}"
        end

        def components(request)
          if request.body
            %w[@method @target-uri content-digest]
          else
            %w[@method @target-uri]
          end
        end

        def digest(message)
          "sha-256=:#{Base64.strict_encode64(
            OpenSSL::Digest.new('SHA256').digest(message)
          )}:"
        end
      end
    end
  end
end
