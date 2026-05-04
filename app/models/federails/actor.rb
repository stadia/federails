# rbs_inline: enabled

require 'federails/utils/host'
require 'federails/utils/actor'
require 'fediverse/webfinger'

module Federails
  # Model storing _distant_ actors and links to local ones.
  #
  # To make a model act as an actor, use the `Federails::ActorEntity` concern
  #
  # See also:
  #  - https://www.w3.org/TR/activitypub/#actor-objects
  class Actor < ApplicationRecord
    class TombstonedError < StandardError; end

    include Federails::HasUuid
    include Federails::HandlesDeleteRequests

    validates :federated_url, presence: { unless: :entity }, uniqueness: { unless: :local? }
    validates :username, presence: { unless: :local? }
    validates :server, presence: { unless: :local? }
    validates :inbox_url, presence: { unless: :local? }
    validates :outbox_url, presence: { unless: :local? }
    validates :followers_url, presence: { unless: :local? }
    validates :followings_url, presence: { unless: :local? }
    validates :profile_url, presence: { unless: :local? }
    validates :actor_type, presence: { unless: :local? }
    validates :entity_id, uniqueness: { scope: :entity_type }, if: :entity_type
    validates :entity, presence: true, if: -> { local? && !tombstoned? }

    belongs_to :entity, polymorphic: true, optional: true
    # FIXME: Handle this with something like undelete
    has_many :activities, dependent: :destroy
    has_many :activities_as_entity, class_name: 'Federails::Activity', as: :entity, dependent: :destroy
    has_many :following_followers, class_name: 'Federails::Following', foreign_key: :target_actor_id, dependent: :destroy, inverse_of: :target_actor
    has_many :following_follows, class_name: 'Federails::Following', dependent: :destroy, inverse_of: :actor
    # Actors following actor
    has_many :followers, source: :actor, through: :following_followers
    # Actors followed by actor
    has_many :follows, source: :target_actor, through: :following_follows

    # Accepted follow relationships for public collections
    has_many :accepted_following_followers, -> { accepted }, class_name: 'Federails::Following', foreign_key: :target_actor_id, dependent: :destroy, inverse_of: :target_actor
    has_many :accepted_following_follows, -> { accepted }, class_name: 'Federails::Following', dependent: :destroy, inverse_of: :actor
    # Actors following actor (accepted only)
    has_many :accepted_followers, source: :actor, through: :accepted_following_followers
    # Actors followed by actor (accepted only)
    has_many :accepted_follows, source: :target_actor, through: :accepted_following_follows

    has_many :featured_items, dependent: :destroy
    has_many :featured_tags, dependent: :destroy
    belongs_to :host, class_name: 'Federails::Host', foreign_key: :server, primary_key: :domain, inverse_of: :actors, optional: true

    # Explicitly explain serialization for MariaDB
    attribute :extensions, :json

    scope :local, -> { where(local: true) }
    scope :distant, -> { where(local: false) }
    scope :tombstoned, -> { where.not(tombstoned_at: nil) }
    scope :not_tombstoned, -> { where(tombstoned_at: nil) }

    after_create -> { FetchNodeinfoJob.perform_later(server) }, unless: :local?

    on_federails_delete_requested -> { tombstone! }
    on_federails_undelete_requested -> { untombstone! }

    #: () -> bool
    def distant?
      !local?
    end

    #: () -> String?
    def federated_url
      use_entity_attributes? ? Federails::Engine.routes.url_helpers.server_actor_url(self) : attributes['federated_url'].presence
    end

    #: () -> String?
    def username
      return attributes['username'] unless use_entity_attributes?

      entity.send(entity_configuration[:username_field]).to_s
    end

    #: () -> String?
    def name
      value = (entity.send(entity_configuration[:name_field]).to_s if use_entity_attributes?)

      value || attributes['name'] || username
    end

    #: () -> String?
    def server
      use_entity_attributes? ? Utils::Host.localhost : attributes['server']
    end

    #: () -> String?
    def actor_type
      use_entity_attributes? ? entity_configuration[:actor_type] : attributes['actor_type']
    end

    #: () -> String?
    def inbox_url
      use_entity_attributes? ? Federails::Engine.routes.url_helpers.server_actor_inbox_url(self) : attributes['inbox_url']
    end

    #: () -> String?
    def outbox_url
      use_entity_attributes? ? Federails::Engine.routes.url_helpers.server_actor_outbox_url(self) : attributes['outbox_url']
    end

    #: () -> String?
    def followers_url
      use_entity_attributes? ? Federails::Engine.routes.url_helpers.followers_server_actor_url(self) : attributes['followers_url']
    end

    #: () -> String?
    def followings_url
      use_entity_attributes? ? Federails::Engine.routes.url_helpers.following_server_actor_url(self) : attributes['followings_url']
    end

    #: () -> String?
    def shared_inbox_url
      if use_entity_attributes?
        Federails::Engine.routes.url_helpers.server_shared_inbox_url
      else
        attributes['shared_inbox_url']
      end
    end

    #: () -> String?
    def profile_url
      return attributes['profile_url'].presence unless use_entity_attributes?

      method = entity_configuration[:profile_url_method]
      return Federails::Engine.routes.url_helpers.server_actor_url self unless method

      Rails.application.routes.url_helpers.send method, [entity]
    end

    #: (?prefix: String) -> String
    def at_address(prefix: '@')
      "#{prefix}#{username}@#{server}"
    end

    #: () -> String
    def short_at_address
      use_entity_attributes? ? "@#{username}" : at_address
    end

    #: () -> String
    def acct_uri
      "acct:#{username}@#{server}"
    end

    #: (String) -> Federails::FeaturedItem
    def feature(federated_url)
      featured_items.find_or_create_by!(federated_url: federated_url)
    end

    #: (String) -> Federails::FeaturedItem?
    def unfeature(federated_url)
      featured_items.find_by(federated_url: federated_url)&.destroy!
    end

    # Checks if a given actor follows the current actor
    #: (Federails::Actor) -> (Federails::Following | false)
    def follows?(actor)
      list = following_follows.where target_actor: actor
      return list.first if list.one?

      false
    end

    # Checks if current actor is followed by the given actor
    #: (Federails::Actor) -> (Federails::Following | false)
    def followed_by?(actor)
      list = following_followers.where actor: actor
      return list.first if list.one?

      false
    end

    #: () -> Hash[Symbol, untyped]
    def entity_configuration
      raise("Entity not configured for #{entity_type}. Did you use \"acts_as_federails_actor\"?") unless Federails.actor_entity? entity_type

      Federails.actor_entity entity_type
    end

    # Synchronizes actor with distant data
    #
    # @raise [ActiveRecord::RecordNotFound] when distant data was not found
    #: () -> bool
    def sync!
      if local?
        Federails.logger.info 'Ignored attempt to sync a local actor'
        return false
      end

      response = Fediverse::Webfinger.fetch_actor_url(federated_url)
      new_attributes = response.attributes.except 'id', 'uuid', 'created_at', 'updated_at', 'local', 'entity_id', 'entity_type'

      update! new_attributes
    end

    #: () -> bool
    def tombstoned?
      tombstoned_at.present?
    end

    #: () -> Federails::Actor
    def tombstone!
      Federails::Utils::Actor.tombstone! self
    end

    #: () -> void
    def untombstone!
      Federails::Utils::Actor.untombstone! self
    end

    class << self
      # Searches for an actor from account URI
      #
      # @param account [String] Account URI (username@host)
      # @return [Federails::Actor, nil]
      #: (String) -> Federails::Actor
      def find_by_account(account)
        parts = Fediverse::Webfinger.split_account account
        if parts.nil? || parts[:username].blank?
          Federails.logger.debug { "Invalid actor account format for lookup: #{account.inspect}" }
          raise ActiveRecord::RecordNotFound
        end

        if Fediverse::Webfinger.local_user? parts
          actor = find_local_by_username! parts[:username]
        else
          actor = find_by username: parts[:username], server: parts[:domain]
          actor ||= Fediverse::Webfinger.fetch_actor(parts[:username], parts[:domain])
        end

        actor
      end

      #: (String?) -> Federails::Actor?
      def find_by_federation_url(federated_url)
        return find_by_account(federated_url) if federated_url.present? && !federated_url.match?(%r{\Ahttps?://}i) && Fediverse::Webfinger.split_account(federated_url)

        local_route = Utils::Host.local_route federated_url
        return find_param(local_route[:id]) if local_route && local_route[:controller] == 'federails/server/actors' && local_route[:action] == 'show'

        actor = find_by federated_url: federated_url
        return actor if actor

        Fediverse::Webfinger.fetch_actor_url(federated_url)
      end

      #: (String?) -> Federails::Actor
      def find_by_federation_url!(federated_url)
        find_by_federation_url(federated_url).tap do |actor|
          raise Federails::Actor::TombstonedError if actor.tombstoned?
          raise ActiveRecord::RecordNotFound if actor.nil?
        end
      end

      #: (String) -> Federails::Actor
      def find_or_create_by_account(account)
        actor = find_by_account account
        # Create/update distant actors
        actor.save! unless actor.local?

        actor
      end

      #: (String?) -> Federails::Actor
      def find_or_create_by_federation_url(url)
        actor = find_by_federation_url url
        # Create/update distant actors
        actor.save! unless actor.local?

        actor
      end

      # Find or create actor from a given actor hash or actor id (actor's URL)
      #: (String | Hash[String, untyped]) -> Federails::Actor
      def find_or_create_by_object(object)
        case object
        when String
          find_or_create_by_federation_url object
        when Hash
          find_or_create_by_federation_url object['id']
        else
          raise "Unsupported object type for actor (#{object.class})"
        end
      end

      #: (String) -> Federails::Actor?
      def find_local_by_username(username)
        actor = nil
        Federails::Configuration.actor_types.each_value do |entity|
          break if actor.present?

          actor = entity[:class].find_by(entity[:username_field] => username)&.federails_actor
        end
        return actor if actor

        # Last hope: Search for tombstoned actors
        Federails::Actor.local.tombstoned.find_by username: username
      end

      #: (String) -> Federails::Actor
      def find_local_by_username!(username)
        find_local_by_username(username).tap do |actor|
          raise ActiveRecord::RecordNotFound if actor.nil?
        end
      end
    end

    #: () -> String?
    def public_key
      ensure_key_pair_exists!
      self[:public_key]
    end

    #: () -> String?
    def private_key
      ensure_key_pair_exists!
      self[:private_key]
    end

    #: () -> String
    def key_id
      "#{federated_url}#main-key"
    end

    private

    #: () -> void
    def ensure_key_pair_exists!
      return if self[:private_key].present? || !local?

      update!(generate_key_pair)
    end

    #: () -> Hash[Symbol, String]
    def generate_key_pair
      rsa_key = OpenSSL::PKey::RSA.new 2048
      cipher  = OpenSSL::Cipher.new('AES-128-CBC')
      {
        private_key: if Rails.application.credentials.secret_key_base
                       rsa_key.to_pem(cipher, Rails.application.credentials.secret_key_base)
                     else
                       rsa_key.to_pem
                     end,
        public_key:  rsa_key.public_key.to_pem,
      }
    end

    #: () -> bool
    def use_entity_attributes?
      local? && !tombstoned? && entity.present?
    end
  end
end
