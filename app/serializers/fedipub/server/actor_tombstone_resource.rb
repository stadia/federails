# rbs_inline: enabled

module Fedipub
  module Server
    class ActorTombstoneResource < BaseResource
      attribute :@context do
        Fedipub::SerializerSupport.json_ld_context
      end

      attribute :id, &:federated_url
      attribute :type do
        'Tombstone'
      end
      attribute :deleted, &:tombstoned_at
      attribute :formerType do |actor|
        actor.attributes['actor_type'] || actor.entity_configuration[:actor_type]
      end
    end
  end
end
