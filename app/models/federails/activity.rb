module Federails
  class Activity < ApplicationRecord
    include Federails::HasUuid

    belongs_to :entity, polymorphic: true
    belongs_to :actor

    scope :feed_for, lambda { |actor|
      actor_ids = []
      Following.accepted.where(actor: actor).find_each do |following|
        actor_ids << following.target_actor_id
      end
      where(actor_id: actor_ids)
    }

    after_create_commit :post_to_inboxes

    def recipients
      return [] unless actor.local?

      case entity_type
      when 'Federails::Following'
        [(action == 'Accept' ? entity.actor : entity.target_actor)]
      else
        actor.followers
      end
    end

    private

    def post_to_inboxes
      NotifyInboxJob.perform_later(self)
    end
  end
end
