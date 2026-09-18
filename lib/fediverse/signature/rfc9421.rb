# typed: true
# rbs_inline: enabled

require 'linzer'
require 'linzer/faraday'
require 'linzer/rack'

Linzer::Message.register_adapter ActionDispatch::Request, Linzer::Message::Adapter::Rack::Request

module Fediverse
  module Signature
    class Rfc9421
      CONTENT_DIGESTS = {
        'sha-256' => 'SHA256',
        'sha-512' => 'SHA512',
      }.freeze

      class << self
        #: (sender: Fedipub::Actor, request: untyped) -> untyped
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

        #: (request: untyped) -> untyped
        def verify!(request:)
          return false unless complete_rfc9421_headers?(request)

          Linzer.verify!(request) do |key_id|
            sender = Fedipub::Actor.find_or_create_by_federation_url(key_id.split('#', 2).first) #: Fedipub::Actor?
            raise Fediverse::Signature::BadSignature if sender.nil?

            linzer_public_key(sender)
          end
          verify_content_digest!(request)
          true
        rescue Linzer::Error, ActiveRecord::RecordNotFound
          raise Fediverse::Signature::BadSignature
        end

        private

        # Converts key to right structure for Linzer to use
        def linzer_private_key(sender)
          private_key = OpenSSL::PKey::RSA.new sender.private_key, Rails.application.credentials.secret_key_base
          Linzer.new_rsa_v1_5_sha256_key(private_key.to_pem, sender.key_id)
        end

        def linzer_public_key(sender)
          public_key = OpenSSL::PKey::RSA.new(sender.public_key)
          Linzer.new_rsa_v1_5_sha256_key(public_key.to_pem, sender.key_id)
        rescue OpenSSL::PKey::PKeyError, ArgumentError, TypeError
          raise Fediverse::Signature::BadSignature
        end

        def components(request)
          if request.body
            %w[@method @target-uri content-digest]
          else
            %w[@method @target-uri]
          end
        end

        def complete_rfc9421_headers?(request)
          has_input = request.headers.key?('Signature-Input')
          has_signature = request.headers.key?('Signature')
          raise Fediverse::Signature::BadSignature if has_input && !has_signature

          has_input && has_signature
        end

        def verify_content_digest!(request)
          body = request_body(request)
          return unless body && !body.to_s.empty?

          raise Fediverse::Signature::BadSignature, 'Content-Digest not signed' unless signed_content_digest?(request)
          raise Fediverse::Signature::BadSignature, 'Content-Digest mismatch' unless matching_content_digest?(request.headers['Content-Digest'], body)
        end

        def signed_content_digest?(request)
          Linzer::Signature.build(
            'signature-input' => request.headers['Signature-Input'].to_s,
            'signature'       => request.headers['Signature'].to_s
          ).components.include?('content-digest')
        end

        def matching_content_digest?(header, body)
          return false if header.blank?

          dict = Linzer::HTTP::StructuredField.parse_dictionary(header)
          digest_body = body.to_s
          CONTENT_DIGESTS.any? do |name, algorithm|
            dict[name]&.value == OpenSSL::Digest.new(algorithm).digest(digest_body)
          end
        rescue Linzer::Error
          false
        end

        def request_body(request)
          request.respond_to?(:raw_post) ? request.raw_post : request.body
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
