require 'fediverse/signature'

module Fediverse
  module Signature
    class DraftCavage12
      class << self
        def sign(sender:, request:)
          request.headers['Digest'] = digest(request.body)
          parts = {
            keyId:     sender.key_id,
            headers:   signature_headers.join(' '),
            signature: signature(sender: sender, request: request),
          }
          request.headers['Signature'] = parts.map { |k, v| "#{k}=\"#{v}\"" }.join(',')
          request
        end

        def verify(sender:, request:)
          raise 'No draft-cavage-12 signature found' unless request.headers['Signature']

          signature_header = request.headers['Signature'].split(',').to_h do |pair|
            /\A(?<key>\w+)="(?<value>.*)"\z/ =~ pair
            [key, value]
          end

          headers   = signature_header['headers']
          signature = Base64.decode64(signature_header['signature'])
          key       = OpenSSL::PKey::RSA.new(sender.public_key)

          comparison_string = Fediverse::Signature.signature_payload(request: request, headers: headers)

          key.verify(OpenSSL::Digest.new('SHA256'), signature, comparison_string)
        end

        private

        def digest(message)
          "SHA-256=#{Base64.strict_encode64(
            OpenSSL::Digest.new('SHA256').digest(message)
          )}"
        end

        def signature_payload(request:)
          Fediverse::Signature.signature_payload(request: request, headers: signature_headers)
        end

        def signature_headers
          %w[(request-target) host date digest]
        end

        def signature(sender:, request:)
          private_key = OpenSSL::PKey::RSA.new sender.private_key, Rails.application.credentials.secret_key_base
          Base64.strict_encode64(
            private_key.sign(
              OpenSSL::Digest.new('SHA256'),
              signature_payload(request: request)
            )
          )
        end
      end
    end
  end
end
