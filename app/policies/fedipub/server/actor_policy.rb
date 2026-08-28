# rbs_inline: enabled

module Fedipub
  module Server
    class ActorPolicy < Fedipub::FedipubPolicy
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

      class Scope < Fedipub::FedipubPolicy::Scope
        def resolve
          scope.local
        end
      end
    end
  end
end
