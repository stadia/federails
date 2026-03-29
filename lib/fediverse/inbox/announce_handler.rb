module Fediverse
  class Inbox
    module AnnounceHandler
      class << self
        def handle_announce(activity)
          actor_url = activity['actor']
          object = activity['object']

          # If object is inline (Hash) with signature, verify it
          if object.is_a?(Hash) && object['signature']
            ld_result = Fediverse::LinkedDataSignature.verify(object)
            if ld_result && !ld_result[:verified]
              Federails.logger.warn "LD Signature verification failed for Announce inner object: #{ld_result[:error]}"
            end
          end

          object_url = object.is_a?(Hash) ? object['id'] : object
          actor = Federails::Actor.find_or_create_by_federation_url(actor_url)
          return false unless actor

          entity = Federails::Utils::Object.find_or_initialize(object_url)

          Federails::Activity.create!(
            action: 'Announce',
            actor: actor,
            entity: entity,
            federated_url: activity['id']
          )
          true
        end

        def handle_undo_announce(activity)
          object = activity['object']
          announce_url = object.is_a?(Hash) ? object['id'] : object
          announce = Federails::Activity.find_by(federated_url: announce_url, action: 'Announce')
          return false unless announce

          announce.destroy!
          true
        end
      end
    end
  end
end
