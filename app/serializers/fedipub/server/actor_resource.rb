# rbs_inline: enabled

module Fedipub
  module Server
    class ActorResource < BaseResource
      FEP_844E_CONTEXT = 'https://w3id.org/fep/844e'.freeze
      IMPLEMENTS = [
        'https://www.w3.org/TR/activitypub/',
        'https://datatracker.ietf.org/doc/html/rfc9421',
        'https://datatracker.ietf.org/doc/html/draft-cavage-http-signatures-12',
        FEP_844E_CONTEXT,
      ].freeze
      # Discovery specs, only implemented when the discovery routes are enabled
      DISCOVERY_IMPLEMENTS = [
        'https://w3id.org/fep/2677', # NodeInfo
        'https://w3id.org/fep/d556', # WebFinger
      ].freeze

      attribute :@context do |actor|
        data = actor_data(actor)
        toot_context = {
          'toot'         => 'http://joinmastodon.org/ns#',
          'featured'     => { '@id' => 'toot:featured', '@type' => '@id' },
          'featuredTags' => { '@id' => 'toot:featuredTags', '@type' => '@id' },
        }
        additional = ['https://w3id.org/security/v1', toot_context, data.delete(:@context)]
        additional << FEP_844E_CONTEXT if actor.application_actor?
        Fedipub::SerializerSupport.json_ld_context(additional: additional)
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
        { sharedInbox: Fedipub::SerializerSupport.route_helpers.server_shared_inbox_url } if actor.local?
      end

      attribute :liked do |actor|
        Fedipub::SerializerSupport.route_helpers.liked_server_actor_url(actor) if actor.local?
      end

      attribute :featured do |actor|
        Fedipub::SerializerSupport.route_helpers.featured_server_actor_url(actor) if actor.local?
      end

      attribute :featuredTags do |actor|
        Fedipub::SerializerSupport.route_helpers.featured_tags_server_actor_url(actor) if actor.local?
      end

      attribute :publicKey do |actor|
        next unless actor.public_key

        {
          id:           actor.key_id,
          owner:        actor.federated_url,
          publicKeyPem: actor.public_key,
        }
      end

      # FEP-844e capability discovery
      attribute :implements do |actor|
        next unless actor.application_actor?

        implements = IMPLEMENTS
        implements += DISCOVERY_IMPLEMENTS if Fedipub::Configuration.enable_discovery
        implements.map { |url| { 'href' => url } }
      end

      attribute :generator do |actor|
        Fedipub::Actor.application_actor.federated_url unless actor.application_actor?
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
