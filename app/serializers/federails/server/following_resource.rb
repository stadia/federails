module Federails
  module Server
    class FollowingResource < BaseResource
      attribute :@context do |_following|
        Federails::SerializerSupport.json_ld_context if params.fetch(:context, true)
      end

      attribute :id, &:federated_url
      attribute :type do
        'Follow'
      end
      attribute :actor do |following|
        following.actor.federated_url
      end
      attribute :object do |following|
        following.target_actor.federated_url
      end
    end
  end
end
