# typed: true
# rbs_inline: enabled

module Fediverse
  module Signature
    class BadSignature < StandardError; end
    SignatureVerificationError = BadSignature

    class << self
      #: (sender: Fedipub::Actor, request: untyped, ?legacy_signature: bool) -> untyped
      def sign(sender:, request:, legacy_signature: false)
        if legacy_signature
          Fediverse::Signature::DraftCavage12.sign(sender: sender, request: request)
        else
          Fediverse::Signature::Rfc9421.sign(sender: sender, request: request)
        end
      end

      #: (request: untyped, ?require_signature: bool) -> bool
      def verify!(request:, require_signature: false) # rubocop:disable Naming/PredicateMethod
        success = Fediverse::Signature::Rfc9421.verify!(request: request) ||
                  Fediverse::Signature::DraftCavage12.verify!(request: request)
        raise(BadSignature) if require_signature && !success

        true
      end
    end
  end
end

require 'fediverse/signature/draft_cavage12'
require 'fediverse/signature/rfc9421'
