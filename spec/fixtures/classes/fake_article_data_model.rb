module Fixtures
  module Classes
    # Model configured as a FederailsDataEntity. It handles Note object from the federation.
    class FakeArticleDataModel < ApplicationRecord
      self.table_name = 'posts'
      include Federails::DataEntity

      acts_as_federails_data handles:             'CustomNote',
                             actor_entity_method: :user,
                             route_path_segment:  :articles

      belongs_to :user, optional: true

      def to_activitypub_object
        Federails::DataTransformer::Note.to_federation self,
                                                       content: content,
                                                       name:    title
      end

      def self.from_activitypub_object(hash)
        {
          title:           hash['name'] || 'A post',
          content:         hash['content'],
          federails_actor: Federails::Actor.find_by_federation_url(hash['actor']),
        }
      end
    end
  end
end
