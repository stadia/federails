# typed: true
# rbs_inline: enabled

require 'fediverse/request'

module Fediverse
  class Inbox
    module FollowHandler
      class << self
        # Creates a Following record from an incoming Follow activity.
        #: (Hash[String, untyped]) -> Fedipub::Following
        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def handle_create_follow_request(activity)
          actor = Fedipub::Actor.find_or_create_by_object(activity['actor'])
          target_actor = Fedipub::Actor.find_or_create_by_object(activity['object'])

          follow_activity = inbound_follow_activity(actor: actor, target_actor: target_actor, activity: activity)
          following = Fedipub::Following.find_or_initialize_by(actor: actor, target_actor: target_actor)
          if following.new_record?
            following.federated_url = activity['id']
            following.save!
            follow_activity ||= following.follow_activity
            return following if actor.local?

            dispatch_followed_callback(target_actor, following, follow_activity)
          else
            follow_activity ||= following.follow_activity
            following.update!(federated_url: activity['id']) if following.federated_url.blank? && activity['id'].present?
            resend_accept_for_duplicate_follow(following, follow_activity) if following.accepted?
          end

          following
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        # Marks a pending Following as accepted when the target actor confirms.
        #: (Hash[String, untyped]) -> Fedipub::Activity?
        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def handle_accept_follow_request(activity)
          original_activity = Request.dereference(activity['object'])
          unless original_activity
            Fedipub.logger.warn { "Follow activity could not be dereferenced: #{activity['object']}" }
            return
          end

          actor = Fedipub::Actor.find_or_create_by_object(original_activity['actor'])
          target_actor = Fedipub::Actor.find_or_create_by_object(original_activity['object'])
          raise 'Follow not accepted by target actor but by someone else' if activity['actor'] != target_actor.federated_url

          follow = Fedipub::Following.find_by(actor: actor, target_actor: target_actor)
          unless follow
            Fedipub.logger.warn do
              "Follow not found for #{actor.federated_url} -> #{target_actor.federated_url}. " \
                "Original activity id: #{activity['object']}"
            end
            return
          end

          follow_activity = follow.follow_activity
          unless follow_activity
            Fedipub.logger.warn do
              "Follow activity not found for #{actor.federated_url} -> #{target_actor.federated_url}. " \
                "Original activity id: #{activity['object']}"
            end
            return
          end

          follow.accept!(follow_activity: follow_activity)
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        # Destroys a Following record when the follower undoes their Follow.
        #: (Hash[String, untyped]) -> Fedipub::Following?
        def handle_undo_follow_request(activity)
          original_activity = activity['object']
          original_activity = Request.dereference(original_activity) if original_activity.is_a?(String)
          return unless original_activity

          actor = Fedipub::Actor.find_or_create_by_object(original_activity['actor'])
          target_actor = Fedipub::Actor.find_or_create_by_object(original_activity['object'])

          follow = Fedipub::Following.find_by(actor: actor, target_actor: target_actor)
          follow&.destroy
        end

        # Destroys a pending Following when the target actor rejects the request.
        # AP Section 7.7: MUST NOT add to Following collection on Reject.
        #: (Hash[String, untyped]) -> Fedipub::Following?
        def handle_reject_follow_request(activity)
          original_activity = Request.dereference(activity['object'])
          unless original_activity
            Fedipub.logger.warn { "Follow activity could not be dereferenced for reject: #{activity['object']}" }
            return
          end

          actor = Fedipub::Actor.find_or_create_by_object(original_activity['actor'])
          target_actor = Fedipub::Actor.find_or_create_by_object(original_activity['object'])
          raise 'Follow not rejected by target actor but by someone else' if activity['actor'] != target_actor.federated_url

          follow = Fedipub::Following.pending.find_by(actor: actor, target_actor: target_actor)
          follow&.destroy
        end

        private

        # Re-sends an Accept Activity when a Follow is received for an already-accepted Following
        # under a new activity id. De-duplication in dispatch_request ensures this path is only
        # reached for genuinely new inbound Follow activities.
        #: (Fedipub::Following, Fedipub::Activity?) -> void
        def resend_accept_for_duplicate_follow(following, follow_activity)
          return unless follow_activity

          follower = following.actor
          return unless follower

          Fedipub::Activity.create!(
            actor:  following.target_actor,
            action: 'Accept',
            entity: follow_activity,
            to:     [follower.federated_url]
          )
        end

        #: (actor: Fedipub::Actor, target_actor: Fedipub::Actor, activity: Hash[String, untyped]) -> Fedipub::Activity?
        # rubocop:disable Metrics/AbcSize
        def inbound_follow_activity(actor:, target_actor:, activity:)
          return Fedipub::Activity.find_by(actor: actor, action: 'Follow', entity: target_actor) if actor.local?

          Fedipub::Activity.find_or_initialize_by(actor: actor, action: 'Follow', entity: target_actor).tap do |follow_activity|
            follow_activity.federated_url = activity['id'] if follow_activity.federated_url.blank? && activity['id'].present?
            follow_activity.to = activity['to'] || [target_actor.federated_url]
            follow_activity.cc = activity['cc']
            follow_activity.bto = activity['bto']
            follow_activity.bcc = activity['bcc']
            follow_activity.audience = activity['audience']
            follow_activity.save! if follow_activity.new_record? || follow_activity.changed?
          end
        end
        # rubocop:enable Metrics/AbcSize

        #: (Fedipub::Actor, Fedipub::Following, Fedipub::Activity?) -> void
        def dispatch_followed_callback(target_actor, following, follow_activity)
          return unless target_actor.entity

          target_actor.entity.class.send(:dispatch_followed_callback, target_actor.entity, following, follow_activity: follow_activity)
        end
      end
    end
  end
end

Fediverse::Inbox.register_handler 'Follow', '*', Fediverse::Inbox::FollowHandler, :handle_create_follow_request
Fediverse::Inbox.register_handler 'Accept', 'Follow', Fediverse::Inbox::FollowHandler, :handle_accept_follow_request
Fediverse::Inbox.register_handler 'Reject', 'Follow', Fediverse::Inbox::FollowHandler, :handle_reject_follow_request
Fediverse::Inbox.register_handler 'Undo', 'Follow', Fediverse::Inbox::FollowHandler, :handle_undo_follow_request
