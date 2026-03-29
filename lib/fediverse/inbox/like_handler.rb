module Fediverse
  class Inbox
    module LikeHandler
      class << self
        def handle_like(activity)
          actor_url = activity['actor']
          object_url = activity['object'].is_a?(Hash) ? activity['object']['id'] : activity['object']
          actor = Federails::Actor.find_or_create_by_federation_url(actor_url)
          return false unless actor

          entity = Federails::Utils::Object.find_or_initialize(object_url)

          Federails::Activity.create!(
            action: 'Like',
            actor: actor,
            entity: entity,
            federated_url: activity['id']
          )
          true
        end

        def handle_undo_like(activity)
          object = activity['object']
          like_url = object.is_a?(Hash) ? object['id'] : object
          like = Federails::Activity.find_by(federated_url: like_url, action: 'Like')
          return false unless like

          like.destroy!
          true
        end
      end
    end
  end
end
