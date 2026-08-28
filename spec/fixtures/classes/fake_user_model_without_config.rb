module Fixtures
  module Classes
    # User model with an incomplete Fedipub::ActorEntity configuration
    class FakeUserModelWithoutConfig < ApplicationRecord
      self.table_name = 'users'
      include Fedipub::ActorEntity
    end
  end
end
