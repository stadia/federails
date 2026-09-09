require 'fediverse/signature'

module Fediverse
  class Notifier
    class << self
      # Posts an activity to its recipients
      #
      # @param activity [Fedipub::Activity]
      def post_to_inboxes(activity)
        # Get the list of actors we need to send the activity to
        inboxes = inboxes_for(activity)
        Rails.logger.debug('Nobody to notice') && return if inboxes.none?

        # Deliver to each inbox
        message = payload(activity)
        inboxes.each do |url|
          Rails.logger.debug { "Sending activity ##{activity.id} to inbox at #{url}" }
          Fedipub::Utils::JsonRequest.post(url: url, message: message, from: activity.actor)
        end
      end

      private

      # Determines the list of inboxes that the activity should be delivered to
      #
      # @return [Array<Fedipub::Actor>]
      def inboxes_for(activity)
        return [] unless activity.actor.local?

        [activity.to, activity.cc].flatten.compact.reject { |x| x == Fediverse::Collection::PUBLIC }.map do |url|
          actor = Fedipub::Actor.find_or_create_by_federation_url(url)
          [actor.inbox_url]
        rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
          collection_to_actors(url).map(&:inbox_url)
        end.flatten.compact
      end

      def collection_to_actors(url)
        collection = Collection.fetch(url)
        collection.filter_map do |actor_url|
          Fedipub::Actor.find_or_create_by_federation_url(actor_url)
        rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
          nil
        end
      rescue Errors::NotACollection
        []
      end

      def payload(activity)
        Fedipub::ServerController.renderer.new.render(
          template: 'fedipub/server/activities/show',
          assigns:  { activity: activity },
          format:   :json
        )
      end
    end
  end
end
