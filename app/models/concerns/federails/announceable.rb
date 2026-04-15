module Federails
  module Announceable
    extend ActiveSupport::Concern

    # Announces (boosts) this entity by creating a new Activity.
    #
    # @param actor [Federails::Actor] The actor doing the announce; defaults to the entity's own actor.
    #
    # @return [Federails::Activity] the newly-created Announce activity
    def announce!(actor: nil)
      actor ||= try(:federails_actor) || self
      create_federails_activity('Announce',
                                actor: actor,
                                to:    [Fediverse::Collection::PUBLIC],
                                cc:    [actor.followers_url])
    end
  end
end
