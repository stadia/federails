require 'fediverse/request'

module Fediverse
  class Inbox
    @@handlers = {} # rubocop:todo Style/ClassVars
    class << self
      # Registers a handler for incoming data
      #
      # Unless a specific type is not implemented in Federails, you should leave the 'Delete' activity to Federails:
      # it will dispatch a `on_federails_delete_requested` event on the right objects.
      #
      # @param activity_type [String] Target activity type ('Create', 'Follow', 'Like', ...)
      #   See https://www.w3.org/TR/activitystreams-vocabulary/#activity-types for a list of common ones
      # @param object_type [String] Type of the related object ('Article', 'Note', ...)
      #   See https://www.w3.org/TR/activitystreams-vocabulary/#object-types for a list of common object types
      # @param klass [String] Class handling the incoming object
      # @param method [Symbol] Method in the class that will handle the object
      def register_handler(activity_type, object_type, klass, method)
        @@handlers[activity_type] ||= {}
        @@handlers[activity_type][object_type] ||= {}
        @@handlers[activity_type][object_type][klass] = method
      end

      # Executes the registered handler for an incoming object
      #
      # @param payload [Hash] Dereferenced activity
      def dispatch_request(payload)
        return dispatch_delete_request(payload) if payload['type'] == 'Delete'

        payload['object'] = Fediverse::Request.dereference(payload['object']) if payload.key? 'object'

        handlers = get_handlers(payload['type'], payload.dig('object', 'type'))
        handlers.each_pair do |klass, method|
          klass.send method, payload
        end
        return true unless handlers.empty?

        Rails.logger.debug { "Unhandled activity type: #{payload['type']}" }
        false
      end

      private

      def dispatch_delete_request(payload)
        payload['object'] = payload['object']['id'] unless payload['object'].is_a? String
        object = Federails::Utils::Object.find_distant_object_in_all payload['object']
        return if object.blank?

        object.run_callbacks :on_federails_delete_requested
      end

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

      def handle_accept_follow_request(activity)
        original_activity = Request.dereference(activity['object'])

        actor        = Federails::Actor.find_or_create_by_object original_activity['actor']
        target_actor = Federails::Actor.find_or_create_by_object original_activity['object']
        raise 'Follow not accepted by target actor but by someone else' if activity['actor'] != target_actor.federated_url

        follow = Federails::Following.find_by actor: actor, target_actor: target_actor
        follow.accept!
      end

      def handle_undo_follow_request(activity)
        original_activity = activity['object']

        actor        = Federails::Actor.find_or_create_by_object original_activity['actor']
        target_actor = Federails::Actor.find_or_create_by_object original_activity['object']

        follow = Federails::Following.find_by actor: actor, target_actor: target_actor
        follow&.destroy
      end

      def handle_delete_request(activity)
        object = Federails::Utils::Object.find_distant_object_in_all(activity['object'])
        return if object.blank?

        object.run_callbacks :on_federails_delete_requested
      end

      def handle_undelete_request(activity)
        # Get to original object
        delete_activity = Request.dereference(activity['object'])
        object = Federails::Utils::Object.find_distant_object_in_all(delete_activity['object'])
        return if object.blank?

        object.run_callbacks :on_federails_undelete_requested
      end
    end

    register_handler 'Follow', '*', self, :handle_create_follow_request
    register_handler 'Accept', 'Follow', self, :handle_accept_follow_request
    register_handler 'Undo', 'Follow', self, :handle_undo_follow_request
    register_handler 'Delete', '*', self, :handle_delete_request
    register_handler 'Undo', 'Delete', self, :handle_undelete_request
  end
end
