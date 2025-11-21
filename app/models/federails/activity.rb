module Federails
  # Activities can be compared to a log of what happened in the Fediverse.
  #
  # Activities from local actors ends in the actors _outboxes_.
  # Activities form distant actors comes from the actor's _inbox_.
  # We try to only keep activities _from_ local actors, and external activities _targetting_ local actors.
  #
  # See also:
  #   - https://www.w3.org/TR/activitypub/#outbox
  #   - https://www.w3.org/TR/activitypub/#inbox
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

    serialize :cc, coder: YAML
    serialize :to, coder: YAML

    # Determines the list of actors targeted by the activity
    #
    # @return [Array<Federails::Actor>]
    def recipients
      return [] unless actor.local?

      case action
      when 'Follow'
        [entity]
      when 'Undo'
        [entity.entity]
      when 'Accept'
        [entity.actor]
      else
        default_recipient_list
      end
    end

    # Generates URLs for the `to` field of the Activity
    # Mirrors `recipients` for Follow/Undo/Accept activities, and makes everything else public.
    #
    # @return [String]
    def to
      case action
      when 'Follow'
        [entity.federated_url]
      when 'Undo'
        [entity.entity.federated_url]
      when 'Accept'
        [entity.actor.federated_url]
      else
        # Everything is public for now
        [Fediverse::Collections::PUBLIC]
      end
    end

    # Generates URLs for the `cc` field of the Activity
    # Mirrors `recipients` for non-Follow/Undo/Accept activities
    #
    # @return [String]
    def cc
      case action
      when 'Follow', 'Undo', 'Accept'
        nil
      else
        # This mirrors default_recipient_list
        [
          actor.followers_url,
          (entity.try(:followers_url) if entity&.local?),
        ].compact.uniq
      end
    end

    private

    def default_recipient_list
      list = actor.followers
      # If local actor is the subject, notify that actor's followers as well
      list += entity.followers if entity.is_a?(Federails::Actor) && entity.local?
      list.uniq
    end

    def post_to_inboxes
      NotifyInboxJob.perform_later(self)
    end
  end
end
