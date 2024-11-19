require 'fediverse/request'

module Fediverse
  class Inbox
    @@handlers = {} # rubocop:todo Style/ClassVars
    class << self
      def register_handler(activity_type, object_type, klass, method)
        @@handlers[activity_type] ||= {}
        @@handlers[activity_type][object_type] ||= {}
        @@handlers[activity_type][object_type][klass] = method
      end

      def dispatch_request(payload)
        handlers = get_handlers(payload['type'], payload.dig('object', 'type'))
        handlers.each_pair do |klass, method|
          klass.send method, payload
        end
        return unless handlers.empty?

        # FIXME: Fails silently
        # raise NotImplementedError
        Rails.logger.debug { "Unhandled activity type: #{payload['type']}" }
      end

      private

      def get_handlers(activity_type, object_type)
        {}.merge(@@handlers.dig(activity_type, object_type) || {})
          .merge(@@handlers.dig(activity_type, '*') || {})
          .merge(@@handlers.dig('*', '*') || {})
          .merge(@@handlers.dig('*', object_type) || {})
      end

      def handle_create_follow_request(activity)
        actor        = Federails::Actor.find_or_create_by_object activity['actor']
        target_actor = Federails::Actor.find_or_create_by_object activity['object']

        Federails::Following.create! actor: actor, target_actor: target_actor, federated_url: activity['id']
      end

      def handle_accept_request(activity)
        original_activity = Request.get(activity['object'])

        actor        = Federails::Actor.find_or_create_by_object original_activity['actor']
        target_actor = Federails::Actor.find_or_create_by_object original_activity['object']
        raise 'Follow not accepted by target actor but by someone else' if activity['actor'] != target_actor.federated_url

        follow = Federails::Following.find_by actor: actor, target_actor: target_actor
        follow.accept!
      end

      def handle_undo_request(activity)
        original_activity = activity['object']

        actor        = Federails::Actor.find_or_create_by_object original_activity['actor']
        target_actor = Federails::Actor.find_or_create_by_object original_activity['object']

        follow = Federails::Following.find_by actor: actor, target_actor: target_actor
        follow&.destroy
      end
    end

    register_handler 'Follow', '*', self, :handle_create_follow_request
    register_handler 'Accept', 'Follow', self, :handle_accept_request
    register_handler 'Undo', 'Follow', self, :handle_undo_request
  end
end
