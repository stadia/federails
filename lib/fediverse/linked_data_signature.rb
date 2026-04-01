module Fediverse
  module LinkedDataSignature
    class << self
      def verify(document)
        signature = document['signature']
        return { verified: false, error: 'No signature block' } unless signature

        actor = resolve_actor(signature)
        return actor if actor.is_a?(Hash)

        to_verify = build_verification_string(document, signature)
        verified = verify_with_retry(actor, signature['signatureValue'], to_verify)
        { verified: verified, actor: actor }
      rescue StandardError => e
        { verified: false, error: e.message }
      end

      private

      def resolve_actor(signature)
        creator_uri = signature['creator']&.sub(/#.*\z/, '')
        return { verified: false, error: 'No creator in signature' } unless creator_uri

        actor = Federails::Actor.find_or_create_by_federation_url(creator_uri)
        return { verified: false, error: 'Could not resolve signing actor' } unless actor
        return { verified: false, error: 'Actor has no public key' } if actor.public_key.blank?

        actor
      end

      # Retries with a refreshed key if the first verification fails and the actor is stale.
      # This prevents unnecessary network requests on every failed verification (e.g., tampered signatures).
      def verify_with_retry(actor, signature_value, to_verify)
        verified = check_signature(actor, signature_value, to_verify)
        return verified if verified || !actor.respond_to?(:sync!)
        return false unless actor.updated_at < Federails::Configuration.remote_entities_cache_duration.ago

        actor.sync!
        check_signature(actor, signature_value, to_verify)
      end

      # Excludes 'type', 'id', and 'signatureValue' from signature options per LD Signatures spec.
      # Note: excluding 'type' is also required for Misskey/Calckey compatibility.
      def build_verification_string(document, signature)
        options_hash = hash_options(signature.except('type', 'id', 'signatureValue'))
        document_hash = hash_document(document.except('signature'))
        options_hash + document_hash
      end

      def check_signature(actor, signature_value, to_verify)
        signature_bytes = Base64.strict_decode64(signature_value)
        public_key = OpenSSL::PKey::RSA.new(actor.public_key)
        public_key.verify(OpenSSL::Digest.new('SHA256'), signature_bytes, to_verify)
      end

      def hash_options(options)
        options = options.merge('@context' => 'https://w3id.org/identity/v1')
        normalized = normalize(options)
        OpenSSL::Digest::SHA256.hexdigest(normalized)
      end

      def hash_document(document)
        normalized = normalize(document)
        OpenSSL::Digest::SHA256.hexdigest(normalized)
      end

      def normalize(document)
        JSON::LD::API.toRdf(document).map(&:to_s).sort.join
      end
    end
  end
end
