# rbs_inline: enabled

module Fedipub
  module Server
    class ActivityPolicy < Fedipub::FedipubPolicy
      def outbox?
        true
      end
    end
  end
end
