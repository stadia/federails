module Fediverse
  module Signature
    class << self
      def sign(sender:, request:)
        Fediverse::Signature::DraftCavage12.sign(sender: sender, request: request)
      end

      def verify(sender:, request:)
        Fediverse::Signature::DraftCavage12.verify(sender: sender, request: request)
      end
    end
  end
end

require 'fediverse/signature/draft_cavage12'
