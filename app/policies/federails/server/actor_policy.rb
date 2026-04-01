module Federails
  module Server
    class ActorPolicy < Federails::FederailsPolicy
      def show?
        @record.local?
      end

      def following?
        true
      end

      def followers?
        true
      end

      def liked?
        true
      end

      def featured?
        true
      end

      def featured_tags?
        true
      end

      class Scope < Scope
        def resolve
          scope.local
        end
      end
    end
  end
end
