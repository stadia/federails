# rbs_inline: enabled

module Fediverse
  class Inbox
    module ActivityHandler
      # rubocop:disable Naming/PredicateMethod

      private

      def process_activity(activity, action)
        actor = Federails::Actor.find_or_create_by_federation_url(activity['actor'])
        return false unless actor

        object_url = activity['object'].is_a?(Hash) ? activity['object']['id'] : activity['object']
        entity = Federails::Utils::Object.find_or_initialize(object_url)

        Federails::Activity.create!(
          action:        action,
          actor:         actor,
          entity:        entity,
          federated_url: activity['id']
        )
        true
      end

      def process_undo_activity(activity, action)
        object = activity['object']
        activity_url = object.is_a?(Hash) ? object['id'] : object
        existing_activity = Federails::Activity.find_by(federated_url: activity_url, action: action)
        return false unless existing_activity
        return false unless existing_activity.actor&.federated_url == activity['actor']

        existing_activity.destroy!
        true
      end
      # rubocop:enable Naming/PredicateMethod
    end
  end
end
