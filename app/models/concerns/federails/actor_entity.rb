module Federails
  # Concern to include in models that acts as actors.
  #
  # Actors can be anything; they authors content _via_ their _outbox_ and receive content in their _inbox_.
  # Actors can follow and be followed by each other
  #
  # By default, when an entry is created on models using this concern, a _local_ `Federails::Actor` will be created.
  #
  # See also:
  #  - https://www.w3.org/TR/activitypub/#actor-objects
  #
  # ## Usage
  #
  # Include the concern in an existing model:
  #
  # ```rb
  # class User < ApplicationRecord
  #   include Federails::ActorEntity
  #   acts_as_federails_actor options
  # end
  # ```
  module ActorEntity
    extend ActiveSupport::Concern

    # Class methods automatically included in the concern.
    module ClassMethods
      # Configures the mapping between entity and actor
      #
      # @param username_field [Symbol] The method or attribute name that returns the preferred username for ActivityPub
      # @param name_field [Symbol] The method or attribute name that returns the preferred name for ActivityPub
      # @param profile_url_method [Symbol] The route method name that will generate the profile URL for ActivityPub
      # @param actor_type [String] The ActivityStreams Actor type for this entity; defaults to 'Person'
      # @param user_count_method [Symbol] A class method to call to count active users. Leave unspecified to leave this
      #   entity out of user counts. Method signature should accept a single parameter which will specify a date range
      #   If parameter is nil, the total user count should be returned. If the parameter is specified, the number of users
      #   active during the time period should be returned.
      # @param auto_create_actors [Boolean] Whether to automatically create an actor when the entity is created
      #
      # @example
      #   acts_as_federails_actor username_field: :username, name_field: :display_name, profile_url_method: :url_for, actor_type: 'Person'
      # rubocop:disable Metrics/ParameterLists
      def acts_as_federails_actor(
        name_field:,
        username_field:,
        profile_url_method: nil,
        actor_type: 'Person',
        user_count_method: nil,
        auto_create_actors: true
      )
        Federails::Configuration.register_actor_class(
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

      # Define a method that will be called after the entity receives a follow request.
      # The follow request will be passed as an argument to the method.
      #
      # @param method_name [Symbol] The name of the method to call, or a block that will be called directly
      #
      # @example
      #   after_followed :accept_follow
      def after_followed(method_name)
        @after_followed = method_name
      end

      # Define a method that will be called after a follow request made by the entity is accepted
      # The accepted follow request will be passed as an argument to the method.
      #
      # @param method_name [Symbol] The name of the method to call, or a block that will be called directly
      #
      # @example
      #   after_follow_accepted :follow_accepted
      def after_follow_accepted(method_name)
        @after_follow_accepted = method_name
      end

      # Define a method that will be called after an activity has been received
      #
      # @param activity_type [String] The activity action to handle, e.g. 'Create'. If you specify '*', the handler will be called for any activity type.
      # @param object_type [String] The object type to handle, e.g. 'Note'. If you specify '*', the handler will be called for any object type.
      # @param method_name [Symbol] The name of the class method to call. The method will receive the complete activity payload as a parameter.
      #
      # @example
      #   after_activity_received 'Create', 'Note', :create_note
      def after_activity_received(activity_type, object_type, method_name)
        Fediverse::Inbox.register_handler(activity_type, object_type, self, method_name)
      end

      private

      def dispatch_callback(name, instance, *args)
        case name
        when :after_followed
          instance.send(@after_followed, *args) if @after_followed
        when :after_follow_accepted
          instance.send(@after_follow_accepted, *args) if @after_follow_accepted
        end
      end
    end

    included do
      # No "dependent: :xyz" as the "before_destroy" hook should have nullified the actor
      has_one :federails_actor, class_name: 'Federails::Actor', as: :entity # rubocop:disable Rails/HasManyOrHasOneDependent

      after_create :create_federails_actor, if: lambda {
        raise("Entity not configured for #{self.class.name}. Did you use \"acts_as_federails_actor\"?") unless Federails.actor_entity? self

        Federails.actor_entity(self)[:auto_create_actors]
      }
      before_destroy :tombstone_federails_actor!
    end

    # Add custom data to actor responses.
    #
    # Override in your own model to add extra data, which will be merged into the actor response
    # generated by Federails. You can include extra `@context` for activitypub extensions and it will
    # be merged with the main response context.
    #
    # @example
    #   def to_activitypub_object
    #     {
    #       "@context": {
    #         toot: "http://joinmastodon.org/ns#",
    #         attributionDomains: {
    #           "@id": "toot:attributionDomains",
    #           "@type": "@id"
    #         }
    #       },
    #       attributionDomains: [
    #         "example.com"
    #       ]
    #     }
    #   end
    def to_activitypub_object
      {}
    end

    private

    # Result is used to determine if an actor related to this entity should be created as local actor or not
    #
    # Override it in your models if you need distant actors to be related to another entity.
    def create_federails_actor_as_local?
      true
    end

    def create_federails_actor
      Federails::Actor.create_with(local: create_federails_actor_as_local?).find_or_create_by!(entity: self)
    end

    def tombstone_federails_actor!
      federails_actor.tombstone! if federails_actor.present?
    end

    def untombstone_federails_actor!
      federails_actor.untombstone! if federails_actor.present?
    end
  end
end
