module Federails
  module Client
    class ActorsController < Federails::ClientController
      before_action :set_actor, only: [:show]

      # GET /app/actors
      # GET /app/actors.json
      def index
        authorize Federails::Actor, policy_class: Federails::Client::ActorPolicy

        @actors = policy_scope(Federails::Actor, policy_scope_class: Federails::Client::ActorPolicy::Scope).all
        @actors = @actors.local if params[:local_only]
      end

      # GET /app/actors/1
      # GET /app/actors/1.json
      def show
        render_show
      end

      # GET /app/actors/lookup
      # GET /app/actors/lookup.json
      def lookup
        @actor = Federails::Actor.find_by_account account_param
        authorize @actor, policy_class: Federails::Client::ActorPolicy
        render_show
      end

      private

      # Use callbacks to share common setup or constraints between actions.
      def set_actor
        @actor = Federails::Actor.find_param(params[:id])
        authorize @actor, policy_class: Federails::Client::ActorPolicy
      end

      def account_param
        params.require('account').strip
      end

      def render_show
        respond_to do |format|
          if @actor.tombstoned?
            format.html { render :gone, status: :gone }
            format.json { render json: { error: I18n.t('controller.actors.gone') }, status: :gone }
          else
            format.html { render :show }
            format.json { render :show }
          end
        end
      end
    end
  end
end
