module Federails
  module Maintenance
    class ActorsUpdater
      class << self
        # Fetches all distant actors again and update their local copy
        #
        # A block can be passed with two arguments: the actor being updated and the update status
        #
        # @param actors [Integer, Federails::Actor, Array<Federails::Actor>, nil] Actor ID, Actor or list of actors to update.
        #   If nothing is passed, all distant actors are processed
        # @example
        #   Update all distant actors
        #     Federails::Maintenance::ActorUpdater.run
        #   With an actor id:
        #     Federails::Maintenance::ActorUpdater.run 1
        #   With a federated URL:
        #     Federails::Maintenance::ActorUpdater.run 'https://example.com/actor'
        #   With a federated URL:
        #     Federails::Maintenance::ActorUpdater.run ['https://example.com/actors/1', 'https://example.com/actors/1']
        #   With actors:
        #     Federails::Maintenance::ActorUpdater.run Federails::Actor.last(10)
        #   Update all distant actors and puts status for each actor
        #     Federails::Maintenance::ActorUpdater.run {|actor, status| puts "#{actor.federated_url}: #{status}"}
        def run(actors = nil, &block)
          actors_list(actors).each do |actor|
            status = update(actor)

            yield(actor, status) if block
          end
        end

        private

        # Make a list of actors to update from the passed attribute
        def actors_list(param) # rubocop:disable Metrics/PerceivedComplexity, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/AbcSize
          if param.nil?
            Federails::Actor.distant
          elsif param.is_a? String
            [Federails::Actor.distant.find_by!(federated_url: param)]
          elsif param.is_a? Integer
            [Federails::Actor.distant.find(param)]
          elsif param.is_a?(Federails::Actor)
            [param]
          elsif param.respond_to?(:pluck) && param.first.is_a?(Federails::Actor)
            param
          elsif param.is_a?(Array) && param.first.is_a?(String)
            Federails::Actor.distant.where(federated_url: param)
          else
            raise "Cannot extract actors from #{param.class}"
          end
        end

        # @param actor [Federails::Actor]
        def update(actor)
          return :ignored_local if actor.local?

          actor.sync! ? :updated : :failed
        rescue ActiveRecord::RecordNotFound
          :not_found
        rescue StandardError
          :failed
        end
      end
    end
  end
end
