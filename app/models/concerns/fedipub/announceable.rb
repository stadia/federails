module Fedipub
  module Announceable
    extend ActiveSupport::Concern

    # Announces (boosts) this entity by creating a new Activity.
    #
    # @param actor [Fedipub::Actor] The actor doing the announce; defaults to the entity's own actor.
    #
    # @return [Fedipub::Activity] the newly-created Announce activity
    def announce!(actor: nil)
      actor ||= try(:fedipub_actor) || self
      create_fedipub_activity('Announce',
                                actor: actor,
                                to:    [Fediverse::Collection::PUBLIC],
                                cc:    [actor.followers_url])
    end
  end
end
