module Federails
  module Utils
    class Actor
      # List of the attributes computed for local actors
      COMPUTED_ATTRIBUTES = [
        :federated_url,
        :username,
        :name,
        :server,
        :inbox_url,
        :outbox_url,
        :followers_url,
        :followings_url,
        :profile_url,
      ].freeze

      class << self
        # @param actor [Federails::Actor]
        # @return [Federails::Actor]
        def tombstone!(actor)
          if actor.local?
            tombstone_local_actor actor
          else
            tombstone_distant_actor actor
          end

          actor
        end

        private

        def tombstone_local_actor(actor)
          Federails::Actor.transaction do
            hash = {
              tombstoned_at: Time.current,
              entity:        actor.entity || nil,
            }
            # Hardcode attributes depending on the actor's entity
            COMPUTED_ATTRIBUTES.each { |attribute| hash[attribute] = actor.send(attribute) }

            actor.update! hash

            Activity.create! actor: actor, action: 'Delete', entity: actor
          end
        end

        def tombstone_distant_actor(actor)
          actor.update! tombstoned_at: Time.current
        end
      end
    end
  end
end
