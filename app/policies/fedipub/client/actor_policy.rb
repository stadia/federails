# rbs_inline: enabled

module Fedipub
  module Client
    class ActorPolicy < Fedipub::FedipubPolicy
      def lookup?
        true
      end

      class Scope < Fedipub::FedipubPolicy::Scope
        def resolve
          scope
        end
      end
    end
  end
end
