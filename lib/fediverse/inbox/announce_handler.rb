# typed: false
# rbs_inline: enabled

require 'fediverse/request'

module Fediverse
  class Inbox
    module AnnounceHandler
      class << self
        def handle_announce(activity)
          entity = resolve_target_entity(activity['object'])
          return true unless entity

          dispatch_callback(entity, :on_fedipub_announce_received, activity['actor'])
        end

        def handle_undo_announce(activity)
          original_activity = Fediverse::Request.dereference(activity['object'])
          return false unless original_activity && activity['actor'] == original_activity['actor']

          entity = resolve_target_entity(original_activity&.dig('object'))
          return true unless entity

          dispatch_callback(entity, :on_fedipub_undo_announce_received, activity['actor'])
        end

        private

        def dispatch_callback(entity, callback_name, actor)
          previous_actor = entity.current_fedipub_activity_actor
          entity.current_fedipub_activity_actor = actor
          entity.run_callbacks(callback_name) { true }
        ensure
          entity.current_fedipub_activity_actor = previous_actor
        end

        def resolve_target_entity(object)
          entity = Fedipub::Utils::Object.find_or_initialize(object)
          return unless entity.is_a?(Fedipub::DataEntity) && entity.persisted?

          entity
        rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
          nil
        end
      end
    end
  end
end
