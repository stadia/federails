# rbs_inline: enabled

module Fedipub
  module Server
    module VerifySignature
      extend ActiveSupport::Concern

      private

      def verify_http_signature!
        return unless Fedipub::Configuration.verify_signatures
        return if request.headers['Signature'].blank? && request.headers['Signature-Input'].blank?

        @signed_actor = actor_from_signature_key_id(request)
      rescue Fediverse::Signature::BadSignature, Fediverse::Signature::SignatureVerificationError => e
        log_signature_failure(e)
        head :unauthorized
      end

      def actor_from_signature_key_id(request)
        key_id = signature_key_id(request)
        raise Fediverse::Signature::BadSignature, 'missing keyId' if key_id.blank?

        actor = Fedipub::Actor.find_or_create_by_federation_url(key_id.split('#', 2).first)
        raise Fediverse::Signature::BadSignature, "Couldn't find sender" unless actor

        actor
      end

      def signature_key_id(request)
        source = request.headers['Signature-Input'].presence || request.headers['Signature'].presence
        return if source.blank?

        source[/(?:keyid|keyId)="([^"]+)"/, 1]
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
        return true unless @signed_actor

        payload_actor_url = payload['actor'].is_a?(String) ? payload['actor'] : payload.dig('actor', 'id')
        return true if @signed_actor.federated_url == payload_actor_url

        Fedipub.logger.warn "Signature actor mismatch: signed=#{@signed_actor.federated_url} payload=#{payload_actor_url}"
        false
      end
    end
  end
end
