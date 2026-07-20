module Fedipub
  module Client
    class ActorPolicy < Fedipub::FedipubPolicy
      def lookup?
        true
      end

      class Scope < Scope
        def resolve
          scope
        end
      end
    end
  end
end
