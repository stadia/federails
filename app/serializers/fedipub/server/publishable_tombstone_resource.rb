# rbs_inline: enabled

module Fedipub
  module Server
    class PublishableTombstoneResource < BaseResource
      attribute :@context do
        Fedipub::SerializerSupport.json_ld_context
      end

      attribute :id, &:federated_url
      attribute :type do
        'Tombstone'
      end
      attribute :deleted, &:fedipub_tombstoned_at
      attribute :formerType do |publishable|
        publishable.fedipub_data_configuration[:handles]
      end
    end
  end
end
