module Federails
  module Server
    class PublishableResource < BaseResource
      attribute :@context do |publishable|
        next unless params.fetch(:context, true)

        data = publishable_data(publishable)
        activity_streams = 'https://www.w3.org/ns/activitystreams'
        additional = Array(data.delete(:@context)).flatten.compact.uniq
        additional.reject! { |entry| entry == activity_streams }
        additional = additional.presence
        Federails::SerializerSupport.json_ld_context(additional: additional)
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
        normalize_activitypub_hash(publishable.to_activitypub_object || {})
      end
    end
  end
end
