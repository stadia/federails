module Federails
  module Server
    # Controller to render ActivityPub representation of entities configured with Federails::DataEntity
    class PublishedController < Federails::ServerController
      def show
        @publishable = type_scope.find(params[:id])
        authorize @publishable, policy_class: Federails::Server::PublishablePolicy
      end

      private

      def type_scope
        return @type_scope if instance_variable_defined? :@type_scope

        _, config = Federails.configuration.data_types.find { |_, v| v[:route_path_segment].to_s == params[:publishable_type] }
        raise ActiveRecord::RecordNotFound, "Invalid #{params[:publishable_type]} type" unless config

        @type_scope = config[:class].all
      end
    end
  end
end
