module Federails
  module Entity
    extend ActiveSupport::Concern

    included do # rubocop:todo Metrics/BlockLength
      include ActiveSupport::Callbacks
      define_callbacks :followed

      # Define a method that will be called after the entity receives a follow request
      # @param method [Symbol] The name of the method to call, or a block that will be called directly
      # @example
      #   after_followed :accept_follow
      def self.after_followed(method)
        set_callback :followed, :after, method
      end

      # Define a method that will be called after an activity has been received
      # @param activity_type [String] The activity action to handle, e.g. 'Create'. If you specify '*', the handler will be called for any activity type.
      # @param object_type [String] The object type to handle, e.g. 'Note'. If you specify '*', the handler will be called for any object type.
      # @param method [Symbol] The name of the class method to call. The method will receive the complete activity payload as a parameter.
      # @example
      #   after_activity_received 'Create', 'Note', :create_note
      def self.after_activity_received(activity_type, object_type, method)
        Fediverse::Inbox.register_handler(activity_type, object_type, self, method)
      end

      has_one :actor, class_name: 'Federails::Actor', as: :entity, dependent: :destroy

      after_create :create_actor, if: -> { Federails::Configuration.entity_types[self.class.name][:auto_create_actors] }

      # Configures the mapping between entity and actor
      # @param username_field [Symbol] The method or attribute name that returns the preferred username for ActivityPub
      # @param name_field [Symbol] The method or attribute name that returns the preferred name for ActivityPub
      # @param profile_url_method [Symbol] The route method name that will generate the profile URL for ActivityPub
      # @param actor_type [String] The ActivityStreams Actor type for this entity; defaults to 'Person'
      # @param user_count_method [Symbol] A class method to call to count active users. Leave unspecified to leave this
      #  entity out of user counts. Method signature should accept a single parameter which will specify a date range
      #  If parameter is nil, the total user count should be returned. If the parameter is specified, the number of users
      #  active during the time period should be returned.
      # @deprecated @param include_in_user_count [boolean] No longer used; replace with `user_count_method`.
      # @param auto_create_actors [Boolean] Whether to automatically create an actor when the entity is created
      # @example
      #   acts_as_federails_actor username_field: :username, name_field: :display_name, profile_url_method: :url_for, actor_type: 'Person'
      # rubocop:disable Metrics/ParameterLists
      def self.acts_as_federails_actor(
        username_field: Federails::Configuration.user_username_field,
        name_field: Federails::Configuration.user_name_field,
        profile_url_method: Federails.configuration.user_profile_url_method,
        actor_type: 'Person',
        user_count_method: nil,
        auto_create_actors: true
      )
        Federails::Configuration.register_entity(
          self,
          username_field:     username_field,
          name_field:         name_field,
          profile_url_method: profile_url_method,
          actor_type:         actor_type,
          user_count_method:  user_count_method,
          auto_create_actors: auto_create_actors
        )
      end
      # rubocop:enable Metrics/ParameterLists

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
