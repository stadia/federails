# rbs_inline: enabled

module Fedipub
  module Server
    class PublishablePolicy < Fedipub::FedipubPolicy
      def show?
        @record.send(@record.fedipub_data_configuration[:should_federate_method])
      end

      class Scope < Fedipub::FedipubPolicy::Scope
        def resolve
          raise NotImplementedError
        end
      end
    end
  end
end
