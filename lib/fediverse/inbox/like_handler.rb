# rbs_inline: enabled

require 'fediverse/request'

module Fediverse
  class Inbox
    module LikeHandler
      class << self
        def handle_like(activity)
          entity = resolve_target_entity(activity['object'])
          return true unless entity

          entity.run_callbacks(:on_federails_like_received) { true }
        end

        def handle_undo_like(activity)
          original_activity = Fediverse::Request.dereference(activity['object'])
          return false unless original_activity
          return false unless activity['actor'] == original_activity['actor']

          entity = resolve_target_entity(original_activity&.dig('object'))
          return true unless entity

          entity.run_callbacks(:on_federails_undo_like_received) { true }
        end

        private

        def resolve_target_entity(object)
          entity = Federails::Utils::Object.find_or_initialize(object)
          return unless entity.is_a?(Federails::DataEntity)

          entity
        rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
          nil
        end
      end
    end
  end
end
