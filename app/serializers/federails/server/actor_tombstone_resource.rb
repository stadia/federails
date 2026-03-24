module Federails
  module Server
    class ActorTombstoneResource < BaseResource
      attribute :@context do
        Federails::SerializerSupport.json_ld_context
      end

      attribute :id, &:federated_url
      attribute :type do
        'Tombstone'
      end
      attribute :deleted, &:tombstoned_at

      def serializable_hash
        super.tap do |hash|
          hash[:formerType] = object.attributes['actor_type'] || object.entity_configuration[:actor_type]
        end
      end
    end
  end
end
