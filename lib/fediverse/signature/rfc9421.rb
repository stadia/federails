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

        def verify!(request:)
          # Do we have a signature to verify?
          return false if !request.headers.key?('Signature-Input') || !request.headers.key?('Signature')

          check_covered_components!(request)
          verify_with_key_refresh!(request)
          true
        rescue Linzer::Error, ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, OpenSSL::PKey::PKeyError => e
          raise Fediverse::Signature::BadSignature, e.message
        end

        private

        # Verifies the signature, refreshing the sender's key once if it may have been rotated
        def verify_with_key_refresh!(request)
          sender = nil
          verify = lambda do
            Linzer.verify!(request) do |key_id|
              sender = Fedipub::Actor.find_or_create_by_federation_url(key_id.split('#', 2).first)
              raise Fediverse::Signature::BadSignature if sender.nil?

              linzer_public_key(sender)
            end
          end
          verify.call
        rescue Linzer::VerifyError
          raise unless Fediverse::Signature.refresh_stale_sender!(sender)

          verify.call
        end

        def check_covered_components!(request)
          message = Linzer::Message.new(request)
          covered = Linzer::Signature.build(
            'signature-input' => message.header('signature-input'),
            'signature'       => message.header('signature')
          ).components
          missing = %w[@method @target-uri]
          missing += ['content-digest'] if Fediverse::Signature.body?(request)
          missing -= covered
          raise Fediverse::Signature::BadSignature, "Signature does not cover #{missing.join(', ')}" if missing.any?
        end

        # Converts key to right structure for Linzer to use
        def linzer_private_key(sender)
          private_key = OpenSSL::PKey::RSA.new sender.private_key, Rails.application.credentials.secret_key_base
          Linzer.new_rsa_v1_5_sha256_key(private_key.to_pem, sender.key_id)
        end

        def linzer_public_key(sender)
          public_key = OpenSSL::PKey::RSA.new(sender.public_key)
          Linzer.new_rsa_v1_5_sha256_key(public_key.to_pem, sender.key_id)
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
