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

    validates :federated_url, uniqueness: true, allow_nil: true

    belongs_to :entity, polymorphic: true
    belongs_to :actor

    scope :feed_for, lambda { |actor|
      where(actor_id: Following.accepted.where(actor: actor).select(:target_actor_id))
    }

    after_create_commit :post_to_inboxes, if: :deliverable?

    before_validation :set_default_addressing, on: :create

    serialize :cc, coder: YAML
    serialize :to, coder: YAML
    serialize :bto, coder: YAML
    serialize :bcc, coder: YAML
    serialize :audience, coder: YAML

    private

    # Sets up default public-and-followers addressing unless to and cc are already set
    #
    # This retains compatibility with previous behaviour
    def set_default_addressing
      return if to.present? || cc.present? || bto.present? || bcc.present? || audience.present?

      self.to = [Fediverse::Collection::PUBLIC]
      self.cc = [
        actor.followers_url,
        (entity.try(:followers_url) if entity.try(:local?)),
        *Array(entity.try(:federation_reply_recipients)),
      ].compact.uniq
    end

    def post_to_inboxes
      NotifyInboxJob.perform_later(self)
    end

    def deliverable?
      actor.local?
    end
  end
end
