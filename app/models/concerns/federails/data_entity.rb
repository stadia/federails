require 'fediverse/inbox'

module Federails
  # Model concern to include in models for which data is pushed to the Fediverse and comes from the Fediverse.
  #
  # Once included, an activity will automatically be created upon
  #   - entity creation
  #   - entity updates
  #
  # Also, when properly configured, a handler is registered to transform incoming objects and create/update entities
  # accordingly.
  #
  # ## Pre-requisites
  #
  # Model should have the following methods:
  #  - `to_activitypub_object`, returning a valid ActivityPub object
  #  - `self.from_activitypub_object`, returning a hash of valid attributes from a hash of incoming data
  #
  #  Table needs at least:
  #  - `t.string :federated_url, null: true, default: nil`
  #  - `t.references :federails_actor, foreign_key: true, null: true, default: nil
  #
  # Model must have the following attributes:
  # ```rb
  # add_column :posts, :federated_url, :string, null: true, default: nil
  # add_reference :posts, :federails_actor, foreign_key: true, null: true, default: nil
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
  #
  #   # This will be called when a Delete activity comes for the entry. As we don't know how you want to handle it,
  #   # you'll have to implement the behavior yourself.
  #   on_federails_delete_requested :do_something
  #
  #   # This will be called when a Undo activity comes for the entry. The easiest way to handle this case is to re-fetch
  #   # the entity
  #   on_federails_undelete_requested :do_something_else
  #
  #   def to_activitypub_object
  #     Federails::DataTransformer::Note.to_federation self,
  #                                                    content: content,
  #                                                    name:    title
  #   end
  #
  #   # Creates a hash of attributes from incoming Note
  #   def self.from_activitypub_object(hash)
  #     {
  #       title:   hash['name'] || 'A post',
  #       content: hash['content'],
  #     }
  #   end
  # end
  # ```
  #
  # **If your model has a mechanism for soft deletion:**
  # - you can specify some methods names to handle it in Federails responses:
  # - you will need to send the delete activity yourself
  #
  # ```rb
  # acts_as_federails_data handles: 'Note',
  #                        ...,
  #                        soft_deleted_method: :deleted?
  #                        soft_delete_date_method: :deleted_at
  #
  # on_federails_delete_requested :soft_delete!
  # on_federails_undelete_requested :restore_remote_entity!
  #
  # # Method you use to soft-delete entities
  # def soft_delete!
  #   update deleted_at: time.current
  #
  #   send_federails_activity 'Delete' unless local_federails_entity?
  # end
  #
  # # Method you use to restore soft-deleted entities
  # def restore!
  #   update deleted_at: nil
  #
  #   if local_federails_entity?
  #     delete_activity =  Activity.find_by action: 'Delete', entity: self
  #     send_federails_activity 'Undo', entity: delete_activity, actor: federails_actor if delete_activity.present?
  #   end
  # end
  #
  # def restore_remote_entity!
  #   self.deleted_at: nil
  #   federails_sync!
  #   save!
  # end
  # ```
  module DataEntity
    class TombstonedError < StandardError; end

    extend ActiveSupport::Concern
    include Federails::HandlesDeleteRequests

    # Class methods automatically included in the concern.
    module ClassMethods
      # Configures the mapping between entity and Fediverse
      #
      # @param actor_entity_method [Symbol] Method returning an object responding to 'federails_actor', for local content
      # @param url_param [Symbol] Column name of the object ID that should be used in URLs. Defaults to +:id+
      # @param route_path_segment [Symbol] Segment used in Federails routes to display the ActivityPub representation.
      #   Defaults to the pluralized, underscored class name
      # @param handles [String] Type of ActivityPub object handled by this entity type
      # @param with [Symbol] Self class method that will handle incoming objects. Defaults to +:handle_incoming_fediverse_data+
      # @param filter_method [Symbol] Self class method that determines if an incoming object should be handled. Note
      #   that the first model for which this method returns true will be used. If left empty, the model CAN be selected,
      #   so define them if many models handle the same data type.
      # @param should_federate_method [Symbol] method to determine if an object should be federated. If the method returns false,
      #   no create/update activities will happen, and object will not be accessible at federated_url. Defaults to a method
      #   that always returns true.
      # @param soft_deleted_method [Symbol, nil] If the model uses a soft-delete mechanism, this is the method to check
      #   if entity is soft-deleted. This is not required by the spec but greatly encouraged as the app will return a 410
      #   response with a Tombstone object instead of an 404 error.
      # @param soft_delete_date_method [Symbol, nil] Method to get the date of the soft-deletion
      #
      # @example
      #   acts_as_federails_data handles: 'Note', with: :note_handler, route_path_segment: :articles, actor_entity_method: :user
      # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength
      def acts_as_federails_data(
        handles:,
        with: :handle_incoming_fediverse_data,
        route_path_segment: nil,
        actor_entity_method: nil,
        url_param: :id,
        filter_method: nil,
        should_federate_method: :default_should_federate?,
        soft_deleted_method: nil,
        soft_delete_date_method: nil
      )
        route_path_segment ||= name.pluralize.underscore

        Federails::Configuration.register_data_type self,
                                                    route_path_segment:      route_path_segment,
                                                    actor_entity_method:     actor_entity_method,
                                                    url_param:               url_param,
                                                    handles:                 handles,
                                                    with:                    with,
                                                    filter_method:           filter_method,
                                                    should_federate_method:  should_federate_method,
                                                    soft_deleted_method:     soft_deleted_method,
                                                    soft_delete_date_method: soft_delete_date_method

        # NOTE: Delete activities cannot be handled like this as we can't be sure to have the object's type
        Fediverse::Inbox.register_handler 'Create', handles, self, with
        Fediverse::Inbox.register_handler 'Update', handles, self, with
      end
      # rubocop:enable Metrics/ParameterLists, Metrics/MethodLength

      # Instantiates a new instance from an ActivityPub object
      #
      # @param activitypub_object [Hash]
      #
      # @return [self]
      def new_from_activitypub_object(activitypub_object)
        new from_activitypub_object(activitypub_object)
      end

      # Creates or updates entity based on the ActivityPub activity
      #
      # @param activity_hash_or_id [Hash, String] Dereferenced activity hash or ID
      #
      # @return [self]
      def handle_incoming_fediverse_data(activity_hash_or_id)
        activity = Fediverse::Request.dereference(activity_hash_or_id)
        object = Fediverse::Request.dereference(activity['object'])

        entity = Federails::Utils::Object.find_or_create!(object)

        if activity['type'] == 'Update'
          entity.assign_attributes from_activitypub_object(object)

          # Use timestamps from attributes
          entity.save! touch: false
        end

        entity
      end

      def find_untombstoned_by!(**params)
        configuration = Federails.data_entity_configuration(self)
        entity = find_by!(**params)

        raise Federails::DataEntity::TombstonedError if configuration[:soft_deleted_method] && entity.send(configuration[:soft_deleted_method])

        entity
      end
    end

    included do
      belongs_to :federails_actor, class_name: 'Federails::Actor'

      scope :local_federails_entities, -> { where federated_url: nil }
      scope :distant_federails_entities, -> { where.not(federated_url: nil) }

      before_validation :set_federails_actor
      after_create -> { create_federails_activity 'Create' }
      after_update -> { create_federails_activity 'Update' }, unless: :federails_tombstoned?
      after_destroy -> { create_federails_activity 'Delete' }
    end

    # Computed value for the federated URL
    #
    # @return [String]
    def federated_url
      return nil unless send(federails_data_configuration[:should_federate_method])
      return attributes['federated_url'] if attributes['federated_url'].present?

      path_segment = Federails.data_entity_configuration(self)[:route_path_segment]
      url_param = Federails.data_entity_configuration(self)[:url_param]
      Federails::Engine.routes.url_helpers.server_published_url(publishable_type: path_segment, id: send(url_param))
    end

    # Check whether the entity was created locally or comes from the Fediverse
    #
    # @return [Boolean]
    def local_federails_entity?
      attributes['federated_url'].blank?
    end

    def federails_tombstoned?
      federails_data_configuration[:soft_deleted_method] ? send(federails_data_configuration[:soft_deleted_method]) : false
    end

    def federails_tombstoned_at
      federails_data_configuration[:soft_delete_date_method] ? send(federails_data_configuration[:soft_delete_date_method]) : nil
    end

    def federails_data_configuration
      Federails.data_entity_configuration(self)
    end

    def federails_sync!
      if local_federails_entity?
        Rails.logger.info { "Ignored attempt to sync a local #{self.class.name}" }
        return false
      end

      object = Fediverse::Request.dereference(federated_url)

      update! self.class.from_activitypub_object(object)
    end

    private

    def set_federails_actor
      return federails_actor if federails_actor.present?

      self.federails_actor = send(federails_data_configuration[:actor_entity_method])&.federails_actor if federails_data_configuration[:actor_entity_method]

      raise 'Cannot determine actor from configuration' unless federails_actor
    end

    def create_federails_activity(action)
      ensure_federails_configuration!
      return unless local_federails_entity? && send(federails_data_configuration[:should_federate_method])

      Activity.create! actor: federails_actor, action: action, entity: self
    end

    def ensure_federails_configuration!
      raise("Entity not configured for #{self.class.name}. Did you use \"acts_as_federails_data\"?") unless Federails.data_entity? self
    end

    def default_should_federate?
      true
    end
  end
end
