module Fediverse
  module Signature
    class << self
      def sign(sender:, request:, legacy_signature: false)
        if legacy_signature
          Fediverse::Signature::DraftCavage12.sign(sender: sender, request: request)
        else
          Fediverse::Signature::Rfc9421.sign(sender: sender, request: request)
        end
      end

      def verify(request:, require_signature: false)
        Fediverse::Signature::Rfc9421.verify(request: request, require_signature: require_signature) ||
          Fediverse::Signature::DraftCavage12.verify(request: request, require_signature: require_signature)
      end
    end
  end
end

require 'fediverse/signature/draft_cavage12'
require 'fediverse/signature/rfc9421'
