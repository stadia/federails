module Federails
  class FeaturedTag < ApplicationRecord
    belongs_to :actor
    validates :name, presence: true, uniqueness: { scope: :actor_id }
  end
end
