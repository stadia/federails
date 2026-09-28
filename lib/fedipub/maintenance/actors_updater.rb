# typed: true
# rbs_inline: enabled

module Fedipub
  module Maintenance
    class ActorsUpdater
      class << self
        # Fetches all distant actors again and update their local copy
        #
        # A block receives the actor and one of :updated, :tombstoned, :not_found, :failed, :ignored_local.
        # :failed covers unexpected exceptions or an unsuccessful sync without a tombstone.
        #
        # @param actors [Integer, Fedipub::Actor, Array<Fedipub::Actor>, nil] Actor ID, Actor or list of actors to update.
        #   If nothing is passed, all distant actors are processed
        # @example
        #   Update all distant actors
        #     Fedipub::Maintenance::ActorsUpdater.run
        #   With an actor id:
        #     Fedipub::Maintenance::ActorsUpdater.run 1
        #   With a federated URL:
        #     Fedipub::Maintenance::ActorsUpdater.run 'https://example.com/actor'
        #   With a federated URL:
        #     Fedipub::Maintenance::ActorsUpdater.run ['https://example.com/actors/1', 'https://example.com/actors/1']
        #   With actors:
        #     Fedipub::Maintenance::ActorsUpdater.run Fedipub::Actor.last(10)
        #   Update all distant actors and puts status for each actor
        #     Fedipub::Maintenance::ActorsUpdater.run {|actor, status| puts "#{actor.federated_url}: #{status}"}
        def run(actors = nil, &block)
          actors_list(actors).each do |actor|
            status = update(actor)

            yield(actor, status) if block
          end
        end

        private

        # Make a list of actors to update from the passed attribute
        def actors_list(param)
          if param.nil?
            Fedipub::Actor.distant
          elsif param.is_a? String
            [Fedipub::Actor.distant.find_by!(federated_url: param)]
          elsif param.is_a? Integer
            [Fedipub::Actor.distant.find(param)]
          elsif param.is_a?(Fedipub::Actor)
            [param]
          elsif param.respond_to?(:pluck) && param.first.is_a?(Fedipub::Actor)
            param
          elsif param.is_a?(Array) && param.first.is_a?(String)
            Fedipub::Actor.distant.where(federated_url: param)
          else
            raise "Cannot extract actors from #{param.class}"
          end
        end

        #: (Fedipub::Actor) -> Symbol
        def update(actor)
          return :ignored_local if actor.local?

          return :updated if actor.sync!

          actor.tombstoned? ? :tombstoned : :failed
        rescue ActiveRecord::RecordNotFound
          :not_found
        rescue StandardError => e
          Fedipub.logger.warn { "Unable to sync #{actor.federated_url}: #{e.class}: #{e.message}" }
          :failed
        end
      end
    end
  end
end
