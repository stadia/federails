# rbs_inline: enabled

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

      # Dispatches an incoming ActivityPub activity to the appropriate handler.
      #
      # Performs de-duplication (AP Section 5.2), origin verification for Update
      # activities (AP Section 7.3), and records processed activity IDs for
      # future de-duplication.
      #
      # @param payload [Hash] Raw activity JSON from the inbox POST
      # @return [true] when the activity was successfully handled
      # @return [:duplicate] when the activity has already been processed
      # @return [false] when no handler matched or verification failed
      def dispatch_request(payload)
        return :duplicate if payload['id'].present? && Federails::Activity.exists?(federated_url: payload['id'])

        dispatched_at = Time.current

        if payload['type'] == 'Delete'
          result = dispatch_delete_request(payload)
          record_processed_activity(payload, dispatched_at) if result
          return result
        end

        payload['object'] = Fediverse::Request.dereference(payload['object']) if payload.key? 'object'

        if (payload['type'] == 'Update') && !(payload['actor'].present? && payload.dig('object', 'id').present? && same_origin?(payload['actor'], payload.dig('object', 'id')))
          Federails.logger.warn do
            "Rejected Update: origin verification failed (actor: #{payload['actor']}, object: #{payload.dig('object', 'id')})"
          end
          return false
        end

        handlers = get_handlers(payload['type'], payload.dig('object', 'type'))
        handlers.each_pair do |klass, method|
          klass.send method, payload
        end

        if handlers.empty?
          Federails.logger.debug { "Unhandled activity type: #{payload['type']}" }
          return false
        end

        record_processed_activity(payload, dispatched_at)
        true
      end

      # Checks whether an incoming activity should be forwarded to local followers.
      # AP Section 7.1.2: forward when all conditions are met:
      # 1. Activity has not been seen before (handled by dispatch_request de-duplication)
      # 2. to/cc/audience addresses a collection owned by this server
      # 3. inReplyTo/object/target/tag references an object owned by this server
      #
      # @param payload [Hash] The activity payload that was just dispatched
      def maybe_forward(payload)
        return unless references_local_object?(payload)

        collection_urls = addressed_local_collections(payload)
        return if collection_urls.empty?

        Fediverse::Notifier.forward_activity(payload, collection_urls, exclude_actor: payload['actor'])
      end

      private

      # Best-effort recording of processed activity for de-duplication.
      # Uses actor as fallback entity when the actual object cannot be resolved.
      # Failures here must not propagate since the activity was already handled successfully.
      def record_processed_activity(payload, dispatched_at)
        federated_url = payload['id']
        return if federated_url.blank?

        actor = Federails::Actor.find_or_create_by_object(payload['actor'])
        return unless actor

        recent_activity = Federails::Activity.where(actor: actor, action: payload['type'], federated_url: nil)
                                             .where(created_at: dispatched_at..)
                                             .order(created_at: :asc) # oldest = most likely ours
                                             .first

        return recent_activity.update!(federated_url: federated_url) if recent_activity

        entity = entity_for_processed_activity(payload, actor)
        return unless entity

        Federails::Activity.create!(
          actor:         actor,
          action:        payload['type'],
          entity:        entity,
          federated_url: federated_url,
          to:            payload['to'],
          cc:            payload['cc'],
          bto:           payload['bto'],
          bcc:           payload['bcc'],
          audience:      payload['audience']
        )
      rescue StandardError => e
        Federails.logger.warn { "Failed to record processed activity #{federated_url}: #{e.message}" }
      end

      # Handles Delete activities by finding the local object and triggering its delete callback.
      def dispatch_delete_request(payload)
        payload['object'] = payload['object']['id'] unless payload['object'].is_a? String
        object = Federails::Utils::Object.find_distant_object_in_all payload['object']
        return if object.blank?

        object.run_callbacks :on_federails_delete_requested
      end

      # Returns merged handlers matching the given activity and object types,
      # including wildcard ('*') registrations.
      def get_handlers(activity_type, object_type)
        {}.merge(@@handlers.dig(activity_type, object_type) || {})
          .merge(@@handlers.dig(activity_type, '*') || {})
          .merge(@@handlers.dig('*', '*') || {})
          .merge(@@handlers.dig('*', object_type) || {})
      end

      # Creates a Following record from an incoming Follow activity.
      def handle_create_follow_request(activity)
        actor        = Federails::Actor.find_or_create_by_object activity['actor']
        target_actor = Federails::Actor.find_or_create_by_object activity['object']

        following = Federails::Following.find_or_initialize_by actor: actor, target_actor: target_actor
        if following.new_record?
          following.federated_url = activity['id']
          following.save!
        elsif following.federated_url.blank? && activity['id'].present?
          following.update! federated_url: activity['id']
        end

        following
      end

      # Marks a pending Following as accepted when the target actor confirms.
      def handle_accept_follow_request(activity)
        original_activity = Request.dereference(activity['object'])

        actor        = Federails::Actor.find_or_create_by_object original_activity['actor']
        target_actor = Federails::Actor.find_or_create_by_object original_activity['object']
        raise 'Follow not accepted by target actor but by someone else' if activity['actor'] != target_actor.federated_url

        follow = Federails::Following.find_by actor: actor, target_actor: target_actor
        follow.accept!
      end

      # Destroys a Following record when the follower undoes their Follow.
      def handle_undo_follow_request(activity)
        original_activity = activity['object']

        actor        = Federails::Actor.find_or_create_by_object original_activity['actor']
        target_actor = Federails::Actor.find_or_create_by_object original_activity['object']

        follow = Federails::Following.find_by actor: actor, target_actor: target_actor
        follow&.destroy
      end

      # Destroys a pending Following when the target actor rejects the request.
      # AP Section 7.7: MUST NOT add to Following collection on Reject.
      def handle_reject_follow_request(activity)
        original_activity = Request.dereference(activity['object'])

        actor = Federails::Actor.find_or_create_by_object(original_activity['actor'])
        target_actor = Federails::Actor.find_or_create_by_object(original_activity['object'])
        raise 'Follow not rejected by target actor but by someone else' if activity['actor'] != target_actor.federated_url

        follow = Federails::Following.pending.find_by(actor: actor, target_actor: target_actor)
        follow&.destroy
      end

      # Triggers on_federails_delete_requested callback on the matching local object.
      def handle_delete_request(activity)
        object = Federails::Utils::Object.find_distant_object_in_all(activity['object'])
        return if object.blank?

        object.run_callbacks :on_federails_delete_requested
      end

      # Triggers on_federails_undelete_requested callback when an Undo+Delete is received.
      def handle_undelete_request(activity)
        delete_activity = Request.dereference(activity['object'])
        object = Federails::Utils::Object.find_distant_object_in_all(delete_activity['object'])
        return if object.blank?

        object.run_callbacks :on_federails_undelete_requested
      end

      # Compares host and port of two URLs for same-origin verification (AP Section 7.3).
      def same_origin?(actor_url, object_url)
        return false if actor_url.blank? || object_url.blank?

        actor_uri = URI.parse(actor_url)
        object_uri = URI.parse(object_url)
        actor_uri.host == object_uri.host && actor_uri.port == object_uri.port
      rescue URI::InvalidURIError
        false
      end

      # Returns true if to/cc/audience addresses a collection owned by this server.
      def references_local_collection?(payload)
        addressed_local_collections(payload).any?
      end

      # Returns true if inReplyTo, object, target, or tag references an object owned by this server.
      def references_local_object?(payload)
        object = payload['object'].is_a?(Hash) ? payload['object'] : {}
        refs = [
          object['inReplyTo'],
          object['id'],
          payload['target'],
          payload['object'].is_a?(String) ? payload['object'] : nil,
          object.fetch('tag', []).map { |tag| tag.is_a?(Hash) ? tag['href'] || tag['id'] : tag },
        ].flatten.compact

        refs.any? { |url| local_object_reference?(url) }
      end

      # Extracts local collection URLs from to/cc/audience addressing fields.
      def addressed_local_collections(payload)
        [payload['to'], payload['cc'], payload['audience']].flatten.compact.select { |url| local_collection_url?(url) }
      end

      # Checks if a URL resolves to a local followers collection via route recognition.
      # AP Section 7.1.2: forwarding targets followers collections only, not following.
      def local_collection_url?(url)
        route = Federails::Utils::Host.local_route(url)
        route.present? && route[:controller] == 'federails/server/actors' && route[:action] == 'followers'
      rescue URI::InvalidURIError, ActionController::RoutingError
        false
      end

      # Checks if a URL resolves to any local Federails resource via route recognition.
      def local_object_reference?(url)
        route = Federails::Utils::Host.local_route(url)
        return false if route.blank?

        %w[federails/server/actors federails/server/followings federails/server/activities federails/server/published].include?(route[:controller])
      rescue URI::InvalidURIError, ActionController::RoutingError
        false
      end

      # Resolves the entity (polymorphic object) for a processed activity record.
      # Falls back to actor when the actual object cannot be resolved.
      def entity_for_processed_activity(payload, actor)
        object = payload['object']
        return actor if payload['type'] == 'Delete' && object == actor.federated_url
        return actor if object.is_a?(Hash) && object['id'] == actor.federated_url
        return actor if object.nil?

        if object.is_a?(String)
          Federails::Utils::Object.find_distant_object_in_all(object) || actor
        elsif object.is_a?(Hash) && object['id'].present?
          Federails::Utils::Object.find_distant_object_in_all(object['id']) || actor
        else
          actor
        end
      end
    end

    register_handler 'Follow', '*', self, :handle_create_follow_request
    register_handler 'Accept', 'Follow', self, :handle_accept_follow_request
    register_handler 'Reject', 'Follow', self, :handle_reject_follow_request
    register_handler 'Undo', 'Follow', self, :handle_undo_follow_request
    register_handler 'Delete', '*', self, :handle_delete_request
    register_handler 'Undo', 'Delete', self, :handle_undelete_request
  end
end
