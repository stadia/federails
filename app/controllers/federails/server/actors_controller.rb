module Federails
  module Server
    class ActorsController < Federails::ServerController
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
        followings_queries
        render_collection(url_method: :followers_server_actor_url)
      end

      # GET /federation/actors/:id/followers
      # GET /federation/actors/:id/followers.json
      def following
        @actors = @actor.follows.order(created_at: :desc)
        followings_queries
        render_collection(url_method: :following_server_actor_url)
      end

      private

      def render_collection(url_method:)
        @collection_id = send(url_method, @actor)
        @first_page = send(url_method, @actor, page: 1)
        @last_page = send(url_method, @actor, page: @actors.total_pages)
        if @is_page
          @current_page = send(url_method, @actor, page: @actors.current_page)
          @next_page = send(url_method, @actor, page: @actors.next_page) if @actors.next_page
          @prev_page = send(url_method, @actor, page: @actors.prev_page) if @actors.prev_page
          render 'ordered_collection_page'
        else
          render 'ordered_collection'
        end
      end

      # Use callbacks to share common setup or constraints between actions.
      def set_actor
        @actor = Actor.find_param(params[:id])
        authorize @actor, policy_class: Federails::Server::ActorPolicy
      end

      def followings_queries
        @total_actors  = @actors.count
        @actors        = @actors.page(params[:page])
        @is_page       = params[:page].present?
      end
    end
  end
end
