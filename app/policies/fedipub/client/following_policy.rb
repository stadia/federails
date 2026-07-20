module Fedipub
  module Client
    class FollowingPolicy < Fedipub::FedipubPolicy
      def show?
        in_following?
      end

      def destroy?
        in_following?
      end

      def accept?
        in_following? && @record.target_actor_id == @user.fedipub_actor.id
      end

      def follow?
        create?
      end

      class Scope < Scope
        def resolve
          scope.with_actor(@user.fedipub_actor)
        end
      end

      private

      def in_following?
        return false unless user_with_actor?

        @record.actor_id == @user.fedipub_actor&.id || @record.target_actor_id == @user.fedipub_actor&.id
      end
    end
  end
end
