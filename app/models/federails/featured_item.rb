module Federails
  class FeaturedItem < ApplicationRecord
    belongs_to :actor
    validates :federated_url, presence: true, uniqueness: { scope: :actor_id }
  end
end
