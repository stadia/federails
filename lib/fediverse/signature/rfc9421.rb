require 'linzer'
require 'linzer/faraday'

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

        def verify(sender:, request:)
          Linzer.verify!(
            request,
            key: linzer_key(sender)
          )
        rescue Linzer::VerifyError
          false
        end

        private

        # Converts key to right structure for Linzer to use
        def linzer_key(sender)
          private_key = OpenSSL::PKey::RSA.new sender.private_key, Rails.application.credentials.secret_key_base
          Linzer.new_rsa_pss_sha512_key(private_key.to_pem)
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
