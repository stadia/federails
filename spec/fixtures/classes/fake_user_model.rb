module Fixtures
  module Classes
    # User model fully configured to be a Fedipub::ActorEntity
    class FakeUserModel < ApplicationRecord
      self.table_name = 'users'
      include Fedipub::ActorEntity

      acts_as_fedipub_actor username_field: :id, name_field: :email
    end
  end
end
