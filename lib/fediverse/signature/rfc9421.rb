require 'linzer'
require 'linzer/faraday'
require 'linzer/rack'

# Linzer::Message.register_adapter ActionDispatch::Request, Linzer::Message::Adapter::Rack::Request

module Fediverse
  module Signature
    class Rfc9421
      class << self
        def sign(sender:, request:)
          request.headers['Content-Digest'] = digest(request.body) if request.body
          Linzer.sign!(
            request,
            key:        linzer_key(sender),
            components: components(request)
          )
          request
        end

        def verify!(request:) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/PerceivedComplexity
          # Do we have a signature to verify?
          return false if (!request.headers.key?('Signature-Input') || !request.headers.key?('Signature')) && (!request.headers.key?('Signature-Input') || (request.get_header('Signature-Input').blank? || request.get_header('Signature').blank?))

          # Verify the signature
          Linzer.verify!(request.try(:rack_request) || request) do |key_id|
            sender = Fedipub::Actor.find_or_create_by_federation_url(key_id)
            raise Fediverse::Signature::BadSignature if sender.nil?

            linzer_key(sender)
          end
        rescue Linzer::Error
          raise Fediverse::Signature::BadSignature
        end

        private

        # Converts key to right structure for Linzer to use
        def linzer_key(sender)
          private_key = OpenSSL::PKey::RSA.new sender.private_key, Rails.application.credentials.secret_key_base
          Linzer.new_rsa_pss_sha512_key(private_key.to_pem, sender.key_id)
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
