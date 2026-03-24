module Federails
  module Server
    class PublishableTombstoneResource < BaseResource
      attribute :@context do
        Federails::SerializerSupport.json_ld_context
      end

      attribute :id, &:federated_url
      attribute :type do
        'Tombstone'
      end
      attribute :deleted, &:federails_tombstoned_at
      attribute :formerType do |publishable|
        publishable.federails_data_configuration[:handles]
      end
    end
  end
end
