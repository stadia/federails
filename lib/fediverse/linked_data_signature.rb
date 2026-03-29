module Fediverse
  module LinkedDataSignature
    class << self
      def verify(document)
        signature = document['signature']
        return nil unless signature

        creator_uri = signature['creator']&.sub(/#.*\z/, '')
        return { verified: false, error: 'No creator in signature' } unless creator_uri

        actor = Federails::Actor.find_or_create_by_federation_url(creator_uri)
        return { verified: false, error: 'Could not resolve signing actor' } unless actor

        options_hash = hash_options(signature.except('type', 'id', 'signatureValue'))
        document_hash = hash_document(document.except('signature'))
        to_verify = options_hash + document_hash

        signature_bytes = Base64.strict_decode64(signature['signatureValue'])
        public_key = OpenSSL::PKey::RSA.new(actor.public_key)

        verified = public_key.verify(OpenSSL::Digest.new('SHA256'), signature_bytes, to_verify)
        { verified: verified, actor: actor }
      rescue OpenSSL::PKey::PKeyError, ArgumentError => e
        { verified: false, error: e.message }
      end

      private

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
      rescue StandardError => e
        Federails.logger.warn "JSON-LD normalization failed: #{e.message}"
        document.to_json
      end
    end
  end
end
