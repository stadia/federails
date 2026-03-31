# rbs_inline: enabled

module Federails
  module Server
    class ActorsController < Federails::ServerController
      include Federails::Server::RenderCollections

      before_action :set_actor, only: [:show, :followers, :following, :liked, :featured, :featured_tags]

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

      # GET /federation/actors/:id/liked
      def liked
        render_collection(
          collection: Federails::Activity.where(actor: @actor, action: 'Like').order(created_at: :desc),
          actor:      @actor,
          url_helper: :liked_server_actor_url
        ) { |items| items.filter_map { |a| a.entity&.federated_url } }
      end

      # GET /federation/actors/:id/featured
      def featured
        render_collection(
          collection: @actor.featured_items.order(created_at: :desc),
          actor:      @actor,
          url_helper: :featured_server_actor_url
        ) { |items| items.map(&:federated_url) }
      end

      # GET /federation/actors/:id/featured_tags
      def featured_tags
        render_collection(
          collection: @actor.featured_tags.order(created_at: :desc),
          actor:      @actor,
          url_helper: :featured_tags_server_actor_url
        ) do |items|
          base_url = Federails.configuration.site_host
          items.map { |tag| { type: 'Hashtag', href: "#{base_url}/tags/#{tag.name}", name: "##{tag.name}" } }
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
