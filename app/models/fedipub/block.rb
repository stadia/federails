# rbs_inline: enabled

module Fedipub
  class Block < ApplicationRecord
    belongs_to :actor
    belongs_to :target_actor, class_name: 'Fedipub::Actor'

    validates :target_actor_id, uniqueness: { scope: :actor_id }
  end
end
