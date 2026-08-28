# rbs_inline: enabled

module Fedipub
  module Likeable
    extend ActiveSupport::Concern

    # Likes this entity by creating a new Activity.
    #
    # @param actor [Fedipub::Actor] The actor that is doing the liking.
    #
    # @return [Fedipub::Activity] the newly-created Like activity
    def like!(actor:)
      create_fedipub_activity('Like',
                              actor: actor,
                              to:    [Fediverse::Collection::PUBLIC],
                              cc:    [actor.followers_url])
    end

    # Dislikes this entity by creating a new Activity.
    #
    # @param actor [Fedipub::Actor] The actor that is doing the disliking.
    #
    # @return [Fedipub::Activity] the newly-created Dislike activity
    def dislike!(actor:)
      create_fedipub_activity('Dislike',
                              actor: actor,
                              to:    [Fediverse::Collection::PUBLIC],
                              cc:    [actor.followers_url])
    end
  end
end
