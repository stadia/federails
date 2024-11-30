module Federails
  # Model concern to include in models for which data is pushed to the Fediverse and comes from the Fediverse.
  #
  # Once included, an activity will automatically be created upon
  #   - entity creation
  #
  # ## Pre-requisites
  #
  # Model must have a `federated_url` attribute:
  # ```rb
  # add_column :posts, :federated_url, :string, null: true, default: nil
  # ```
  #
  # ## Usage
  #
  # Include the concern in an existing model:
  #
  # ```rb
  # class Post < ApplicationRecord
  #   include Federails::DataEntity
  #   acts_as_federails_data options
  # end
  # ```
  module DataEntity
    extend ActiveSupport::Concern

    # Class methods automatically included in the concern.
    module ClassMethods
      # Configures the mapping between entity and Fediverse
      #
      # Model should have the following methods:
      # - `to_activitypub_object`, returning a valid ActivityPub object
      #
      # @param actor_entity_method [Symbol] Method returning an object responding to 'federails_actor', for local content
      # @param route_path_segment [Symbol] Segment used in Federails routes to display the ActivityPub representation.
      #   Defaults to the pluralized, underscored class name
      #
      # @example
      #   acts_as_federails_data actor_entity_method: :user, route_path_segment: :articles
      def acts_as_federails_data(
        route_path_segment: nil,
        actor_entity_method: nil
      )
        route_path_segment ||= name.pluralize.underscore

        Federails::Configuration.register_data_type self,
                                                    route_path_segment:  route_path_segment,
                                                    actor_entity_method: actor_entity_method
      end
    end

    included do
      belongs_to :federails_actor, class_name: 'Federails::Actor'

      scope :local_federails_entities, -> { where federated_url: nil }
      scope :distant_federails_entities, -> { where.not(federated_url: nil) }

      before_validation :set_federails_actor
      after_create :create_federails_activity
    end

    # Computed value for the federated URL
    #
    # @return [String]
    def federated_url
      return attributes['federated_url'] if attributes['federated_url'].present?

      path_segment = Federails.data_entity_configuration(self)[:route_path_segment]
      Federails::Engine.routes.url_helpers.server_published_url(publishable_type: path_segment, id: id)
    end

    # Check whether the entity was created locally or comes from the Fediverse
    #
    # @return [Boolean]
    def local_federails_entity?
      attributes['federated_url'].blank?
    end

    private

    def set_federails_actor
      return federails_actor if federails_actor.present?

      configuration = Federails.data_entity_configuration(self)
      self.federails_actor = send(configuration[:actor_entity_method])&.federails_actor if configuration[:actor_entity_method]

      raise 'Cannot determine actor from configuration' unless federails_actor
    end

    def create_federails_activity
      ensure_federails_configuration!
      return unless local_federails_entity?

      Activity.create! actor: federails_actor, action: 'Create', entity: self
    end

    def ensure_federails_configuration!
      raise("Entity not configured for #{self.class.name}. Did you use \"acts_as_federails_data\"?") unless Federails.data_entity? self
    end
  end
end
