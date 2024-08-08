module Federails
  module Entity
    extend ActiveSupport::Concern

    included do
      has_one :actor, class_name: 'Federails::Actor', as: :entity, dependent: :destroy

      after_create :create_actor

      # Configures the mapping between entity and actor
      # @param username_field [Symbol] The method or attribute name that returns the preferred username for ActivityPub
      # @param name_field [Symbol] The method or attribute name that returns the preferred name for ActivityPub
      # @param profile_url_method [Symbol] The route method name that will generate the profile URL for ActivityPub
      # @param actor_type [String] The ActivityStreams Actor type for this entity; defaults to 'Person'
      # @param include_in_user_count [boolean] Should this entity be included in the nodeinfo user count? Defaults to true
      # @example
      #   acts_as_federails_actor username_field: :username, name_field: :display_name, profile_url_method: :url_for, actor_type: 'Person'
      def self.acts_as_federails_actor(
        username_field: Federails::Configuration.user_username_field,
        name_field: Federails::Configuration.user_name_field,
        profile_url_method: Federails.configuration.user_profile_url_method,
        actor_type: 'Person',
        include_in_user_count: true
      )
        Federails::Configuration.register_entity(
          self,
          username_field:        username_field,
          name_field:            name_field,
          profile_url_method:    profile_url_method,
          actor_type:            actor_type,
          include_in_user_count: include_in_user_count
        )
      end

      # Automatically run default acts_as_federails_actor
      # this can be optionally called again with different configuration in the entity
      acts_as_federails_actor

      private

      def create_actor
        Federails::Actor.create! entity: self
      end
    end
  end
end
