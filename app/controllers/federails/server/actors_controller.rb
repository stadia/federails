# rbs_inline: enabled

module Federails
  module Server
    class ActorsController < Federails::ServerController
      include Federails::Server::RenderCollections

      before_action :set_actor, only: [:show, :followers, :following]

      # GET /federation/actors/1
      # GET /federation/actors/1.json
      def show
        status = @actor.tombstoned? ? :gone : :ok
        resource_class = @actor.tombstoned? ? Federails::Server::ActorTombstoneResource : Federails::Server::ActorResource
        render_serialized(resource_class, @actor, status: status, content_type: Mime[:activitypub])
      end

      # GET /federation/actors/:id/followers
      # GET /federation/actors/:id/followers.json
      def followers
        render_collection(
          collection: @actor.followers.order(created_at: :desc),
          actor:      @actor,
          url_helper: :followers_server_actor_url
        ) { |items| items.map(&:federated_url) }
      end

      # GET /federation/actors/:id/followers
      # GET /federation/actors/:id/followers.json
      def following
        render_collection(
          collection: @actor.follows.order(created_at: :desc),
          actor:      @actor,
          url_helper: :following_server_actor_url
        ) { |items| items.map(&:federated_url) }
      end

      private

      # Use callbacks to share common setup or constraints between actions.
      def set_actor
        @actor = Actor.find_param(params[:id])
        authorize @actor, policy_class: Federails::Server::ActorPolicy
      end
    end
  end
end
