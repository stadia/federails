module Federails
  module Server
    class ActorResource < BaseResource
      attribute :@context do |actor|
        data = actor_data(actor)
        additional = ['https://w3id.org/security/v1', data.delete(:@context)]
        Federails::SerializerSupport.json_ld_context(additional: additional)
      end

      attribute :id, &:federated_url
      attributes :name
      attribute :type, &:actor_type
      attribute :preferredUsername, &:username
      attribute :inbox, &:inbox_url
      attribute :outbox, &:outbox_url
      attribute :followers, &:followers_url
      attribute :following, &:followings_url
      attribute :url, &:profile_url

      attribute :endpoints do |actor|
        if actor.local?
          { sharedInbox: Federails::SerializerSupport.route_helpers.server_shared_inbox_url }
        end
      end

      attribute :publicKey do |actor|
        next unless actor.public_key

        {
          id:           actor.key_id,
          owner:        actor.federated_url,
          publicKeyPem: actor.public_key,
        }
      end

      def serializable_hash
        actor_data(object).merge(super)
      end

      def actor_data(actor)
        normalize_activitypub_hash(actor.entity&.to_activitypub_object || {})
      end
    end
  end
end
