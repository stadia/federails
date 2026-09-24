module Fediverse
  module Signature
    class BadSignature < StandardError; end

    class << self
      def sign(sender:, request:, legacy_signature: false)
        if legacy_signature
          Fediverse::Signature::DraftCavage12.sign(sender: sender, request: request)
        else
          Fediverse::Signature::Rfc9421.sign(sender: sender, request: request)
        end
      end

      def verify!(request:, require_signature: false) # rubocop:disable Naming/PredicateMethod
        success = Fediverse::Signature::Rfc9421.verify!(request: request) ||
                  Fediverse::Signature::DraftCavage12.verify!(request: request)
        raise(BadSignature) if require_signature && !success

        true
      end

      # Re-fetches a remote sender whose cached data is stale, so a rotated key can be picked up.
      # Returns true if the sender was refreshed and verification is worth retrying.
      def refresh_stale_sender!(sender) # rubocop:disable Naming/PredicateMethod
        return false if sender.nil? || sender.local?
        return false unless sender.updated_at < Fedipub::Configuration.remote_entities_cache_duration.ago

        sender.sync!
        true
      end

      # Whether the request carries a body that the signature must cover
      def body?(request)
        body = request.body
        return body.present? unless body.respond_to?(:read)

        content = body.read
        body.rewind
        content.present?
      end

      # Returns the actor who signed the request, based on the RFC9421 or draft-cavage-12 key id.
      # Only meaningful once the signature has been checked with #verify!
      def signer(request:)
        key_id = request.headers['Signature-Input']&.[](/keyid="([^"]+)"/, 1) ||
                 request.headers['Signature']&.[](/keyId="([^"]+)"/, 1)
        return unless key_id

        Fedipub::Actor.find_or_create_by_federation_url(key_id.split('#', 2).first)
      end
    end
  end
end

require 'fediverse/signature/draft_cavage12'
require 'fediverse/signature/rfc9421'
