module Federails
  module Server
    class ActivityResource < BaseResource
      attribute :'@context' do |_activity|
        Federails::SerializerSupport.json_ld_context if include_context?
      end

      attribute :id do |activity|
        Federails::SerializerSupport.route_helpers.server_actor_activity_url(activity.actor, activity)
      end

      attribute :type, &:action
      attribute :actor do |activity|
        activity.actor.federated_url
      end

      attribute :to do |activity|
        activity.to if include_addressing?
      end

      attribute :cc do |activity|
        activity.cc if include_addressing?
      end

      attribute :audience do |activity|
        activity.try(:audience) if include_addressing?
      end

      attribute :object do |activity|
        serialize_object(activity.entity)
      end

      def include_context?
        params.fetch(:context, true)
      end

      def include_addressing?
        params.fetch(:addressing, true)
      end

      def serialize_object(entity)
        case entity
        when Federails::Activity
          self.class.new(entity, params: { context: false, addressing: false }).serializable_hash
        else
          return entity.to_activitypub_object if entity.respond_to?(:to_activitypub_object)
          return entity.federated_url if entity.respond_to?(:federated_url)

          nil
        end
      end
    end
  end
end
