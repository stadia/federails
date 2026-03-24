module Federails
  module Server
    class ActorsController < Federails::ServerController
      include Federails::Server::RenderCollections

      before_action :set_actor, only: [:show, :followers, :following]

      # GET /federation/actors/1
      # GET /federation/actors/1.json
      def show
        status = @actor.tombstoned? ? :gone : :ok
        render :show, status: status
      end

      # GET /federation/actors/:id/followers
      # GET /federation/actors/:id/followers.json
      def followers
        @actors = @actor.followers.order(created_at: :desc)
        render_collection(
          collection: @actors.page(params[:page]),
          actor:      @actor,
          url_helper: :followers_server_actor_url
        ) do |builder, items|
          builder.array! items.map(&:federated_url)
        end
      end

      # GET /federation/actors/:id/followers
      # GET /federation/actors/:id/followers.json
      def following
        @actors = @actor.follows.order(created_at: :desc)
        render_collection(
          collection: @actors.page(params[:page]),
          actor:      @actor,
          url_helper: :following_server_actor_url
        ) do |builder, items|
          builder.array! items.map(&:federated_url)
        end
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
