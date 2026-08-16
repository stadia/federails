# rbs_inline: enabled

module Federails
  module Server
    class PublishablePolicy < Federails::FederailsPolicy
      def show?
        @record.send(@record.federails_data_configuration[:should_federate_method])
      end

      class Scope < Federails::FederailsPolicy::Scope
        def resolve
          raise NotImplementedError
        end
      end
    end
  end
end
