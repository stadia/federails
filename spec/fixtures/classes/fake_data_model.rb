module Fixtures
  module Classes
    class FakeDataModel < ApplicationRecord
      self.table_name = 'posts'
      include Federails::DataEntity

      acts_as_federails_data actor_entity_method: :user,
                             route_path_segment:  :fake_data

      belongs_to :user, optional: true

      def to_activitypub_object
        Federails::DataTransformer::Note.to_federation self,
                                                       name:    title,
                                                       content: content
      end
    end
  end
end
