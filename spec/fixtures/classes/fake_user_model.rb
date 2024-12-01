module Fixtures
  module Classes
    # User model fully configured to be a Federails::ActorEntity
    class FakeUserModel < ApplicationRecord
      self.table_name = 'users'
      include Federails::ActorEntity

      acts_as_federails_actor username_field: :id, name_field: :email
    end
  end
end
