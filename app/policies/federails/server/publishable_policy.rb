module Federails
  module Server
    class PublishablePolicy < Federails::FederailsPolicy
      class Scope < Scope
        def resolve
          raise NotImplementedError
        end
      end
    end
  end
end
