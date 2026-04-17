module Federails
  module Server
    module VerifySignature
      extend ActiveSupport::Concern

      private

      def verify_http_signature!
        return unless Federails::Configuration.verify_signatures

        @signed_actor = Fediverse::Signature.verify_request!(request)
      rescue Fediverse::Signature::SignatureVerificationError => e
        log_signature_failure(e)
        head :unauthorized
      end

      def log_signature_failure(error)
        Federails.logger.warn do
          {
            message:         "Signature verification failed: #{error.message}",
            remote_ip:       request.remote_ip,
            signature_input: request.headers['Signature-Input'],
            actor:           extract_payload_actor,
          }.inspect
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
        return true unless Federails::Configuration.verify_signatures && @signed_actor

        payload_actor_url = payload['actor'].is_a?(String) ? payload['actor'] : payload.dig('actor', 'id')
        return true if @signed_actor.federated_url == payload_actor_url

        Federails.logger.warn "Signature actor mismatch: signed=#{@signed_actor.federated_url} payload=#{payload_actor_url}"
        false
      end
    end
  end
end
