require 'fediverse/signature/draft_cavage12'

module Fediverse
  module Signature
    def self.sign(sender:, request:)
      Fediverse::Signature::DraftCavage12.sign(sender: sender, request: request)
    end

    def self.verify(sender:, request:)
      Fediverse::Signature::DraftCavage12.verify(sender: sender, request: request)
    end
  end
end
