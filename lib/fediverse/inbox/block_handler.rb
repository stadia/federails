module Fediverse
  class Inbox
    module BlockHandler
      class << self
        def handle_block(activity)
          actor = Federails::Actor.find_or_create_by_federation_url(activity['actor'])
          target_url = activity['object'].is_a?(Hash) ? activity['object']['id'] : activity['object']
          target_actor = Federails::Actor.find_or_create_by_federation_url(target_url)
          return false unless actor && target_actor

          Federails::Block.find_or_create_by!(actor: actor, target_actor: target_actor)

          # Destroy followings in both directions
          Federails::Following.where(actor: actor, target_actor: target_actor).destroy_all
          Federails::Following.where(actor: target_actor, target_actor: actor).destroy_all

          true
        end

        def handle_undo_block(activity)
          object = activity['object']
          actor = Federails::Actor.find_or_create_by_federation_url(activity['actor'])
          target_url = object.is_a?(Hash) ? (object['object'].is_a?(Hash) ? object['object']['id'] : object['object']) : nil
          return false unless actor && target_url

          target_actor = Federails::Actor.find_or_create_by_federation_url(target_url)
          return false unless target_actor

          block = Federails::Block.find_by(actor: actor, target_actor: target_actor)
          return false unless block

          block.destroy!
          true
        end
      end
    end
  end
end
