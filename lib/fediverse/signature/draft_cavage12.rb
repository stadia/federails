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
        # Same limits as Mastodon: accept a Date up to 12h old, and up to 1h in the future for clock skew
        EXPIRATION_WINDOW = 12.hours
        CLOCK_SKEW_MARGIN = 1.hour

        # @return [Fedipub::Actor, false] the signer, or false if the request has no draft-cavage-12 signature
        # @raise [Fediverse::Signature::BadSignature] when the signature is invalid
        def verify!(request:) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
          # Do we have a signature to verify?
          return false unless request.headers.key?('Signature')

          # Have we got what we need?
          components = signature_components(request)
          raise Fediverse::Signature::BadSignature, 'Malformed signature' unless components['signature'] && components['headers']

          check_covered_headers!(request, components['headers'].split)
          check_date!(request)

          sender = Fediverse::Signature.find_sender(components['keyId'])
          comparison_string = signature_payload(request: request, headers: components['headers'])

          # Verify the payload against the signature, refreshing the sender's key once if it may have been rotated
          verified = do_verification(components['signature'], sender, comparison_string) ||
                     (Fediverse::Signature.refresh_stale_sender!(sender) && do_verification(components['signature'], sender, comparison_string))
          raise Fediverse::Signature::BadSignature, "Signature mismatch for keyId #{components['keyId']}" unless verified

          sender
        rescue OpenSSL::PKey::PKeyError => e
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

        def set_headers(request) #  rubocop:disable Naming/AccessorMethodName
          request.headers['Digest'] = digest(request.body) if request.body
          request.headers['Host'] = URI.parse(request.path).host
          request.headers['Date'] = Time.now.utc.httpdate
          request
        end

        def signature_components(request)
          pairs = request.headers['Signature'].split(',').map do |pair|
            /\A(?<key>\w+)="(?<value>.*)"\z/ =~ pair.strip
            [key, value]
          end
          # Duplicated parameters would make the signature ambiguous
          raise Fediverse::Signature::BadSignature, 'Malformed signature' if pairs.map(&:first).uniq.size != pairs.size

          pairs.to_h
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
