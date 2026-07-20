module Fedipub
  module Client
    class ActivitiesController < Fedipub::ClientController
      before_action :authenticate_user!, only: [:feed]
      before_action :authorize_action!

      # GET /app/activities
      # GET /app/activities.json
      def index
        @activities = policy_scope(Fedipub::Activity, policy_scope_class: Fedipub::Client::ActivityPolicy::Scope).all
        @activities = @activities.where actor: Actor.find_param(params[:actor_id]) if params[:actor_id]
      end

      # GET /app/feed
      # GET /app/feed.json
      def feed
        @activities = Activity.feed_for(current_user.fedipub_actor)
      end

      private

      def authorize_action!
        authorize(Fedipub::Activity, policy_class: Fedipub::Client::ActivityPolicy)
      end
    end
  end
end
