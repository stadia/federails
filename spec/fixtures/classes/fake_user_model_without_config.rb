module Fixtures
  module Classes
    # User model with an incomplete Federails::ActorEntity configuration
    class FakeUserModelWithoutConfig < ApplicationRecord
      self.table_name = 'users'
      include Federails::ActorEntity
    end
  end
end
