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

        def untombstone!(actor)
          if actor.local?
            untombstone_local_actor actor
          else
            untombstone_distant_actor actor
          end
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

        def untombstone_local_actor(actor)
          return unless actor.tombstoned?
          raise 'Cannot restore a local actor without an entity' if actor.entity.blank?

          Federails::Actor.transaction do
            # Reset hardcoded attributes depending on the actor's entity
            hash = { tombstoned_at: nil }
            COMPUTED_ATTRIBUTES.each { |attribute| hash[attribute] = nil }

            actor.update! hash

            delete_activity = Activity.find_by actor: actor, action: 'Delete', entity: actor
            return unless delete_activity

            Activity.create! actor: actor, action: 'Undo', entity: delete_activity
          end
        end

        def tombstone_distant_actor(actor)
          actor.update! tombstoned_at: Time.current
        end

        def untombstone_distant_actor(actor)
          actor.tombstoned_at = nil
          actor.sync!
          actor.save
        end
      end
    end
  end
end
