module Fixtures
  module Classes
    # User model configured to be a Federails::ActorEntity, but without auto-creation of actor
    class FakeUserModelWithoutAutoCreation < ApplicationRecord
      self.table_name = 'users'
      include Federails::ActorEntity

      acts_as_federails_actor username_field: :id, name_field: :email, auto_create_actors: false
    end
  end
end
