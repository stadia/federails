module Fediverse
  module Signature
    class BadSignature < StandardError; end

    class << self
      # Errors that can happen while fetching a remote signer; they mean the signature can't be verified.
      # (A method rather than a constant, so this file can be required before Rails is loaded.)
      def sender_fetch_errors
        [ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, Faraday::Error, JSON::ParserError, URI::InvalidURIError]
      end

      def sign(sender:, request:, legacy_signature: false)
        if legacy_signature
          Fediverse::Signature::DraftCavage12.sign(sender: sender, request: request)
        else
          Fediverse::Signature::Rfc9421.sign(sender: sender, request: request)
        end
      end

      # Verifies the request's signature, if it has one.
      #
      # @return [true] when the signature is valid, or when the request is unsigned and signatures are optional
      # @raise [BadSignature] when the signature is invalid, or missing while required
      def verify!(request:, require_signature: false) # rubocop:disable Naming/PredicateMethod
        sender = verify_sender!(request: request)
        raise(BadSignature, 'Missing signature') if require_signature && !sender

        true
      end

      # Verifies the request's signature (RFC9421 first, then draft-cavage-12) and returns the actor whose
      # key was used to verify it, so callers never have to parse the key id again.
      #
      # @return [Fedipub::Actor, nil] the signer, or nil when the request is unsigned
      # @raise [BadSignature] when the signature is invalid
      def verify_sender!(request:)
        Fediverse::Signature::Rfc9421.verify!(request: request) ||
          Fediverse::Signature::DraftCavage12.verify!(request: request) ||
          nil
      end

      # Finds (or fetches) the actor owning a key id
      #
      # @raise [BadSignature] when the actor can't be retrieved or has no public key
      def find_sender(key_id)
        raise BadSignature, 'Missing key id' if key_id.blank?

        sender = Fedipub::Actor.find_or_create_by_federation_url(key_id.split('#', 2).first)
        raise BadSignature, "Couldn't find signer #{key_id}" unless sender
        raise BadSignature, "Actor #{sender.federated_url} has no public key" if sender.public_key.blank?

        sender
      rescue *sender_fetch_errors => e
        raise BadSignature, "Unable to fetch signer #{key_id}: #{e.class}: #{e.message}"
      end

      # Re-fetches a remote sender whose cached data is stale, so a rotated key can be picked up.
      # The sender is touched even when nothing changed, so failing requests can't trigger a fetch every time.
      #
      # @return [Boolean] true if the sender was refreshed and verification is worth retrying
      # @raise [BadSignature] when the refresh fails
      def refresh_stale_sender!(sender)
        return false if sender.nil? || sender.local?
        return false unless sender.updated_at < Fedipub::Configuration.remote_entities_cache_duration.ago

        Fedipub.logger.info { "[Signature] Refreshing #{sender.federated_url} after a failed verification" }
        begin
          sender.sync!
        ensure
          sender.touch # rubocop:disable Rails/SkipsModelValidations
        end
        raise BadSignature, "Actor #{sender.federated_url} has no public key" if sender.public_key.blank?

        true
      rescue *sender_fetch_errors => e
        raise BadSignature, "Unable to refresh signer #{sender.federated_url}: #{e.class}: #{e.message}"
      end

      # Whether the request carries a body that the signature must cover
      def body?(request)
        body = request.body
        return body.present? unless body.respond_to?(:read)

        content = body.read
        body.rewind
        content.present?
      end
    end
  end
end

require 'fediverse/signature/draft_cavage12'
require 'fediverse/signature/rfc9421'
