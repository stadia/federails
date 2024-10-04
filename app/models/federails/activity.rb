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

    def recipients # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
      return [] unless actor.local?

      actors = []
      case action
      when 'Create'
        actors.push(entity.target_actor) if entity_type == 'Federails::Following'
        # FIXME: Move this to dummy, somehow
        actors.push(*actor.followers) if entity_type == 'Note'
      when 'Accept'
        actors.push(entity.actor) if entity_type == 'Federails::Following'
      when 'Undo'
        actors.push(entity.target_actor) if entity_type == 'Federails::Following'
      end

      actors
    end

    private

    def post_to_inboxes
      NotifyInboxJob.perform_later(self)
    end
  end
end
