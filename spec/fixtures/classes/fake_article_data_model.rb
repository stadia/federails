module Fixtures
  module Classes
    # Model configured as a FederailsDataEntity
    class FakeArticleDataModel < ApplicationRecord
      self.table_name = 'posts'
      include Federails::DataEntity

      acts_as_federails_data actor_entity_method: :user

      belongs_to :user, optional: true
    end
  end
end
