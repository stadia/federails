module Fixtures
  module Classes
    # Model configured as a FederailsDataEntity
    class FakeArticleDataModel < ApplicationRecord
      self.table_name = 'posts'
      include Federails::DataEntity

      acts_as_federails_data actor_entity_method: :user,
                             route_path_segment:  :articles

      belongs_to :user, optional: true

      def to_activitypub_object
        Federails::DataTransformer::Note.to_federation self,
                                                       content: content,
                                                       name:    title
      end
    end
  end
end
