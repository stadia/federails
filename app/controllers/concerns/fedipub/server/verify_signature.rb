# rbs_inline: enabled

module Fedipub
  module Server
    module VerifySignature
      extend ActiveSupport::Concern

      CONTENT_DIGEST_ALGORITHMS = { 'sha-256' => 'SHA256', 'sha-512' => 'SHA512' }.freeze
      DIGEST_CHECKS = { 'Content-Digest' => :content_digest_match?, 'Digest' => :digest_match? }.freeze

      private

      def verify_http_signature!
        return unless Fedipub::Configuration.verify_signatures

        Fediverse::Signature.verify!(request: request, require_signature: true)
        verify_body_digest!
        @signed_actor = Fediverse::Signature.signer(request: request)
      rescue Fediverse::Signature::BadSignature => e
        log_signature_failure(e)
        head :unauthorized
      end

      # Signatures only cover the digest headers, so check they actually match the body.
      def verify_body_digest!
        checks = DIGEST_CHECKS.select { |header, _| request.headers[header].present? }
        raise Fediverse::Signature::BadSignature, 'Missing Content-Digest/Digest header' if checks.empty?

        checks.each do |header, check|
          raise Fediverse::Signature::BadSignature, "#{header} mismatch" unless send(check, request.headers[header])
        end
      end

      def content_digest_match?(header)
        header.scan(/([A-Za-z0-9-]+)=:([^:]+):/).any? do |algorithm, value|
          digest_name = CONTENT_DIGEST_ALGORITHMS[algorithm.downcase]
          digest_name && ActiveSupport::SecurityUtils.secure_compare(value, body_digest(digest_name))
        end
      end

      def digest_match?(header)
        ActiveSupport::SecurityUtils.secure_compare(header, "SHA-256=#{body_digest('SHA256')}")
      end

      def body_digest(digest_name)
        body = request.body.read
        request.body.rewind
        Base64.strict_encode64(OpenSSL::Digest.new(digest_name).digest(body))
      end

      def log_signature_failure(error)
        Fedipub.logger.warn do
          {
            message:         "Signature verification failed: #{error.message}",
            remote_ip:       request.remote_ip,
            signature_input: request.headers['Signature-Input'],
            actor:           extract_payload_actor,
          }
        end
      end

      def extract_payload_actor
        body = request.body.tap(&:rewind).read
        JSON.parse(body)['actor']
      rescue StandardError
        nil
      ensure
        request.body.rewind
      end

      def actor_match?(payload)
        return true unless Fedipub::Configuration.verify_signatures && @signed_actor

        payload_actor_url = payload['actor'].is_a?(String) ? payload['actor'] : payload.dig('actor', 'id')
        return true if @signed_actor.federated_url == payload_actor_url

        Fedipub.logger.warn "Signature actor mismatch: signed=#{@signed_actor.federated_url} payload=#{payload_actor_url}"
        false
      end
    end
  end
end
