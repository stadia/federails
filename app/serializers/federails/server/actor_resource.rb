module Federails
  module Server
    class ActorResource < BaseResource
      attribute :@context do |actor|
        data = actor_data(actor)
        toot_context = {
          'toot'         => 'http://joinmastodon.org/ns#',
          'featured'     => { '@id' => 'toot:featured', '@type' => '@id' },
          'featuredTags' => { '@id' => 'toot:featuredTags', '@type' => '@id' },
        }
        additional = ['https://w3id.org/security/v1', toot_context, data.delete(:@context)]
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
        { sharedInbox: Federails::SerializerSupport.route_helpers.server_shared_inbox_url } if actor.local?
      end

      attribute :liked do |actor|
        Federails::SerializerSupport.route_helpers.liked_server_actor_url(actor) if actor.local?
      end

      attribute :featured do |actor|
        Federails::SerializerSupport.route_helpers.featured_server_actor_url(actor) if actor.local?
      end

      attribute :featuredTags do |actor|
        Federails::SerializerSupport.route_helpers.featured_tags_server_actor_url(actor) if actor.local?
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
