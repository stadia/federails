module Federails
  module Server
    class ActorsController < Federails::ServerController
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
        @actors = @actor.followers.order(created_at: :desc)
        followings_queries
        render_serialized(
          Federails::Server::OrderedCollectionResource,
          ordered_collection_payload(
            collection_id:  @actor.followers_url,
            page_url:       ->(page) { Federails::Engine.routes.url_helpers.followers_server_actor_url(@actor, page: page) },
            total_items:    @total_actors,
            ordered_items:  @actors.map(&:federated_url)
          ),
          content_type: Mime[:activitypub]
        )
      end

      # GET /federation/actors/:id/followers
      # GET /federation/actors/:id/followers.json
      def following
        @actors = @actor.follows.order(created_at: :desc)
        followings_queries
        render_serialized(
          Federails::Server::OrderedCollectionResource,
          ordered_collection_payload(
            collection_id:  @actor.followings_url,
            page_url:       ->(page) { Federails::Engine.routes.url_helpers.following_server_actor_url(@actor, page: page) },
            total_items:    @total_actors,
            ordered_items:  @actors.map(&:federated_url)
          ),
          content_type: Mime[:activitypub]
        )
      end

      private

      # Use callbacks to share common setup or constraints between actions.
      def set_actor
        @actor = Actor.find_param(params[:id])
        authorize @actor, policy_class: Federails::Server::ActorPolicy
      end

      def followings_queries
        @pagy, @actors = pagy(@actors)
        @total_actors = @pagy.count
      end

      def ordered_collection_payload(collection_id:, page_url:, total_items:, ordered_items:)
        if params[:page].blank?
          Federails::Server::OrderedCollectionPayload.new(
            id:         collection_id,
            type:       'OrderedCollection',
            totalItems: total_items,
            first:      page_url.call(1),
            last:       page_url.call(@pagy.pages == 1 ? 1 : @pagy.pages)
          )
        else
          Federails::Server::OrderedCollectionPayload.new(
            id:           page_url.call(params[:page]),
            type:         'OrderedCollectionPage',
            totalItems:   total_items,
            prev:         @pagy.previous ? page_url.call(@pagy.previous) : nil,
            next:         @pagy.next ? page_url.call(@pagy.next) : nil,
            partOf:       collection_id,
            orderedItems: ordered_items
          )
        end
      end
    end
  end
end
