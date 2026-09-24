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

        REQUIRED_HEADERS = %w[(request-target) host date].freeze
        EXPIRATION_WINDOW = 12.hours
        CLOCK_SKEW_MARGIN = 1.hour

        def verify!(request:) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
          # Do we have a signature to verify?
          return false unless request.headers.key?('Signature')

          # Have we got what we need?
          components = signature_components(request)
          raise Fediverse::Signature::BadSignature, 'Malformed signature' unless components['signature'] && components['headers']

          check_covered_headers!(request, components['headers'].split)
          check_date!(request)

          # Find the sender
          sender = find_sender_by_key_id(components['keyId'])
          raise Fediverse::Signature::BadSignature, "Couldn't find sender" unless sender

          # Build the expected payload
          comparison_string = signature_payload(request: request, headers: components['headers'])

          # Verify the payload against the signature, refreshing the sender's key once if it may have been rotated
          result = do_verification(components['signature'], sender, comparison_string) ||
                   (Fediverse::Signature.refresh_stale_sender!(sender) && do_verification(components['signature'], sender, comparison_string))
          raise Fediverse::Signature::BadSignature unless result

          result
        rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, OpenSSL::PKey::PKeyError => e
          raise Fediverse::Signature::BadSignature, e.message
        end

        private

        def check_covered_headers!(request, headers)
          required = REQUIRED_HEADERS
          required += ['digest'] if Fediverse::Signature.body?(request)
          missing = required - headers.map(&:downcase)
          raise Fediverse::Signature::BadSignature, "Signature does not cover #{missing.join(', ')}" if missing.any?
        end

        def check_date!(request)
          date = Time.httpdate(request.headers['Date'].to_s)
          return if date.between?(EXPIRATION_WINDOW.ago, CLOCK_SKEW_MARGIN.from_now)

          raise Fediverse::Signature::BadSignature, 'Signature date is outside the allowed window'
        rescue ArgumentError
          raise Fediverse::Signature::BadSignature, 'Invalid Date header'
        end

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
              "(request-target): #{(request.try(:http_method) || request.try(:method)).downcase} #{request_target_path(request)}"
            else
              "#{header}: #{request.headers[header.capitalize]}"
            end
          end.join("\n")
        end

        # Path and query string, as sent on the wire
        def request_target_path(request)
          return request.fullpath if request.respond_to?(:fullpath)

          uri = URI.parse(request.path)
          query = request.params.present? ? Faraday::Utils.default_params_encoder.encode(request.params) : uri.query
          query.present? ? "#{uri.path}?#{query}" : uri.path
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
