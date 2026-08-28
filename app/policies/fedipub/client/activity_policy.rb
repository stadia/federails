# rbs_inline: enabled

module Fedipub
  module Client
    class ActivityPolicy < Fedipub::FedipubPolicy
      def feed?
        user_with_actor?
      end
    end
  end
end
