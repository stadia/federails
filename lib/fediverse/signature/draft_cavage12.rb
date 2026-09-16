require 'fediverse/signature'

module Fediverse
  module Signature
    class DraftCavage12
      class << self
        def sign(sender:, request:)
          request = set_headers(request)

          parts = {
            keyId:     sender.key_id,
            headers:   signature_headers(request).join(' '),
            signature: signature(sender: sender, request: request),
          }
          request.headers['Signature'] = parts.map { |k, v| "#{k}=\"#{v}\"" }.join(',')
          request
        end

        def verify!(request:)
          # Do we have a signature to verify?
          return false unless request.headers.key?('Signature')

          # Have we got what we need?
          components = signature_components(request)
          raise Fediverse::Signature::BadSignature, 'Malformed signature' unless components['signature'] && components['headers']

          # Find the sender
          sender = find_sender_by_key_id(components['keyId'])
          raise Fediverse::Signature::BadSignature, "Couldn't find sender" unless sender

          # Build the expected payload
          comparison_string = signature_payload(request: request, headers: components['headers'])

          # Verify the payload against the signature
          result = do_verification(components['signature'], sender, comparison_string)
          raise Fediverse::Signature::BadSignature unless result

          result
        end

        private

        def do_verification(signature, sender, comparison_string)
          signature = Base64.decode64(signature)
          key       = OpenSSL::PKey::RSA.new(sender.public_key)
          key.verify(OpenSSL::Digest.new('SHA256'), signature, comparison_string)
        end

        def find_sender_by_key_id(key_id)
          return unless key_id

          Fedipub::Actor.find_or_create_by_federation_url(
            key_id.split('#', 2).first
          )
        end

        def set_headers(request) #  rubocop:disable Naming/AccessorMethodName
          request.headers['Digest'] = digest(request.body) if request.body
          request.headers['Host'] = URI.parse(request.path).host
          request.headers['Date'] = Time.now.utc.httpdate
          request
        end

        def signature_components(request)
          request.headers['Signature'].split(',').to_h do |pair|
            /\A(?<key>\w+)="(?<value>.*)"\z/ =~ pair
            [key, value]
          end
        end

        def digest(message)
          "SHA-256=#{Base64.strict_encode64(
            OpenSSL::Digest.new('SHA256').digest(message)
          )}"
        end

        def signature_payload(request:, headers: signature_headers(request))
          headers = headers.split if headers.is_a?(String)
          headers.map do |header|
            case header
            when '(request-target)'
              "(request-target): #{(request.try(:http_method) || request.try(:method)).downcase} #{URI.parse(request.path).path}"
            else
              "#{header}: #{request.headers[header.capitalize]}"
            end
          end.join("\n")
        end

        def signature_headers(request)
          if request.body
            %w[(request-target) host date digest]
          else
            %w[(request-target) host date]
          end
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
