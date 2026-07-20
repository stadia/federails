module Fixtures
  module Classes
    # User model configured to be a Fedipub::ActorEntity, but without auto-creation of actor
    class FakeUserModelWithoutAutoCreation < ApplicationRecord
      self.table_name = 'users'
      include Fedipub::ActorEntity

      acts_as_fedipub_actor username_field: :id, name_field: :email, auto_create_actors: false
    end
  end
end
