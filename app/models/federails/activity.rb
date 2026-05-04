# rbs_inline: enabled

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

    # Ensures sensible default addressing is always present.
    #
    # - +to+ defaults to the public collection when not explicitly set.
    # - For public activities (to includes the public collection),
    #   the actor's followers URL and the entity's followers URL (when local)
    #   are always merged into +cc+.
    # - Reply recipients from the entity (+federation_reply_recipients+) are
    #   always merged into +cc+, regardless of activity type.  This ensures
    #   that the original author of a replied-to post is always addressed.
    #: () -> void
    def set_default_addressing
      # Default to public collection when to is not explicitly set.
      self.to = [Fediverse::Collection::PUBLIC] if to.blank?

      # After the line above, to is guaranteed non-empty because we either
      # kept the existing value or defaulted to [PUBLIC].
      default_cc = []

      # Followers are only relevant for public activities
      if Array(to).include?(Fediverse::Collection::PUBLIC)
        default_cc << actor.followers_url
        default_cc << entity.try(:followers_url) if entity.try(:local?)
      end

      # Reply recipients are always included so remote authors receive the reply
      default_cc.concat(Array(entity.try(:federation_reply_recipients)))

      # Only modify cc when we have something to add. This preserves explicit
      # empty arrays ([]) and avoids unexpectedly nil-ing them out.
      self.cc = (Array(cc) + default_cc).compact.uniq.presence if default_cc.any?
    end

    #: () -> void
    def post_to_inboxes
      NotifyInboxJob.perform_later(self)
    end

    #: () -> bool
    def deliverable?
      actor.local?
    end
  end
end
