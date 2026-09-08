require 'fediverse/signature/draft_cavage12'

module Fediverse
  module Signature
    class << self
      delegate :sign, to: Fediverse::Signature::DraftCavage12
      delegate :verify, to: Fediverse::Signature::DraftCavage12
    end
  end
end
