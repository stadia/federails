# typed: true
# rbs_inline: enabled

require 'fediverse/signature'

module Fediverse
  module Signature
    class DraftCavage12
      class << self
        #: (sender: Fedipub::Actor, request: untyped) -> untyped
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

        #: (request: untyped) -> untyped
        def verify!(request:)
          return false unless request.headers.key?('Signature')

          components = parsed_signature_components(request)
          sender = sender_from!(components)
          verify_digest!(request, components['headers'])
          result = do_verification(
            components['signature'],
            sender,
            signature_payload(request: request, headers: components['headers'])
          )
          raise Fediverse::Signature::BadSignature unless result

          result
        end

        private

        def parsed_signature_components(request)
          components = signature_components(request)
          raise Fediverse::Signature::BadSignature, 'Malformed signature' unless components['signature'] && components['headers']

          components
        end

        def sender_from!(components)
          sender = find_sender_by_key_id(components['keyId'])
          raise Fediverse::Signature::BadSignature, "Couldn't find sender" unless sender

          sender
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
        rescue ActiveRecord::RecordNotFound
          nil
        end

        def set_headers(request) #  rubocop:disable Naming/AccessorMethodName
          request.headers['Digest'] = digest(request.body) if request.body
          request.headers['Host'] = URI.parse(request.path).host
          request.headers['Date'] = Time.now.utc.httpdate
          request
        end

        def signature_components(request)
          request.headers['Signature'].split(',').to_h do |pair|
            /\A(?<key>\w+)="(?<value>.*)"\z/ =~ pair.strip
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
              "(request-target): #{(request.try(:http_method) || request.try(:method)).downcase} #{request_target(request)}"
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

        def verify_digest!(request, signed_headers)
          body = request_body(request)
          return unless body_present?(body)

          names = signed_headers.to_s.split.map(&:downcase)
          raise Fediverse::Signature::BadSignature, 'Unsigned digest' unless names.include?('digest')
          raise Fediverse::Signature::BadSignature, 'Digest mismatch' unless request.headers['Digest'] == digest(body)
        end

        def request_body(request)
          if request.respond_to?(:raw_post)
            request.raw_post
          else
            request.body
          end
        end

        def body_present?(body)
          body && !body.to_s.empty?
        end

        def request_target(request)
          return request.fullpath if request.respond_to?(:fullpath)

          uri = URI.parse(request.path.to_s)
          query = request_query(uri, request)
          query.present? ? "#{uri.path}?#{query}" : uri.path
        end

        def request_query(uri, request)
          return uri.query if uri.query.present?
          return unless request.respond_to?(:params)

          params = request.params
          URI.encode_www_form(params) if params.respond_to?(:any?) && params.any?
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
