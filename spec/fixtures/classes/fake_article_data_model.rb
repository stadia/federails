module Fixtures
  module Classes
    # Model configured as a FedipubDataEntity. It handles Note object from the federation.
    class FakeArticleDataModel < ApplicationRecord
      self.table_name = 'posts'
      include Fedipub::DataEntity
      include Fedipub::HandlesDeleteRequests

      acts_as_fedipub_data handles:                 'CustomNote',
                           actor_entity_method:     :user,
                           route_path_segment:      :articles,
                           filter_method:           :handle_incoming_note?,
                           soft_deleted_method:     :deleted?,
                           soft_delete_date_method: :deleted_at

      belongs_to :user, optional: true

      on_fedipub_delete_requested -> { raise 'on_fedipub_delete_requested called' }
      on_fedipub_undelete_requested -> { raise 'on_fedipub_undelete_requested called' }

      def deleted?
        !!deleted_at
      end

      def soft_delete!
        return unless local_fedipub_entity?

        update! deleted_at: Time.current
        create_fedipub_activity('Delete')
      end

      def to_activitypub_object
        Fedipub::DataTransformer::Note.to_federation self,
                                                     content: content,
                                                     name:    title
      end

      # Prevent posts starting with 'Draft:" to be published
      def default_should_federate?
        !title.start_with?('Draft:')
      end

      def self.from_activitypub_object(hash)
        {
          title:   hash['name'] || 'A post',
          content: hash['content'],
        }
      end

      def self.handle_incoming_note?(_activitypub_hash)
        # Perform checks on incoming hash to determine if it needs to be handled by this class
        # and return a boolean.
        true
      end
    end
  end
end
