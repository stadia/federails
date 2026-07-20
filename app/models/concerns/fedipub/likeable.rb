module Federails
  module Likeable
    extend ActiveSupport::Concern

    # Likes this entity by creating a new Activity.
    #
    # @param actor [Federails::Actor] The actor that is doing the liking.
    #
    # @return [Federails::Activity] the newly-created Like activity
    def like!(actor:)
      create_federails_activity('Like',
                                actor: actor,
                                to:    [Fediverse::Collection::PUBLIC],
                                cc:    [actor.followers_url])
    end

    # Dislikes this entity by creating a new Activity.
    #
    # @param actor [Federails::Actor] The actor that is doing the disliking.
    #
    # @return [Federails::Activity] the newly-created Dislike activity
    def dislike!(actor:)
      create_federails_activity('Dislike',
                                actor: actor,
                                to:    [Fediverse::Collection::PUBLIC],
                                cc:    [actor.followers_url])
    end
  end
end
