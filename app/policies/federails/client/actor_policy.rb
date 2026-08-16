# rbs_inline: enabled

module Federails
  module Client
    class ActorPolicy < Federails::FederailsPolicy
      def lookup?
        true
      end

      class Scope < Federails::FederailsPolicy::Scope
        def resolve
          scope
        end
      end
    end
  end
end
