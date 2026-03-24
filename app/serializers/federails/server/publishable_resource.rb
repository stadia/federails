module Federails
  module Server
    class PublishableResource < BaseResource
      attribute :'@context' do |_publishable|
        Federails::SerializerSupport.json_ld_context if params.fetch(:context, true)
      end

      attribute :id, &:federated_url
      attribute :actor do |publishable|
        publishable.federails_actor.federated_url
      end
      attribute :to do
        [Fediverse::Collection::PUBLIC]
      end
      attribute :cc do |publishable|
        [publishable.federails_actor.followers_url]
      end

      def serializable_hash
        publishable_data(object).merge(super)
      end

      def publishable_data(publishable)
        @publishable_data ||= begin
          data = publishable.to_activitypub_object || {}
          data.deep_dup.except(:@context, '@context')
        end
      end
    end
  end
end
