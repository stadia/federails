module Federails
  module Server
    module VerifySignature
      extend ActiveSupport::Concern

      private

      def verify_http_signature!
        return unless Federails::Configuration.verify_signatures

        @signed_actor = Fediverse::Signature.verify_request!(request)
      rescue Fediverse::Signature::SignatureVerificationError => e
        Federails.logger.warn "Signature verification failed: #{e.message}"
        head :unauthorized
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
