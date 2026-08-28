# rbs_inline: enabled

module Fedipub
  module Client
    class ActorsController < Fedipub::ClientController
      before_action :set_actor, only: [:show]

      # GET /app/actors
      # GET /app/actors.json
      def index
        authorize Fedipub::Actor, policy_class: Fedipub::Client::ActorPolicy

        @actors = policy_scope(Fedipub::Actor, policy_scope_class: Fedipub::Client::ActorPolicy::Scope).all
        @actors = @actors.local if params[:local_only]
        render_serialized(Fedipub::Client::ActorResource, @actors) if request.format.json?
      end

      # GET /app/actors/1
      # GET /app/actors/1.json
      def show
        render_show
      end

      # GET /app/actors/lookup
      # GET /app/actors/lookup.json
      def lookup
        @actor = Fedipub::Actor.find_by_account account_param
        authorize @actor, policy_class: Fedipub::Client::ActorPolicy
        render_show
      end

      private

      # Use callbacks to share common setup or constraints between actions.
      def set_actor
        @actor = Fedipub::Actor.find_param(params[:id])
        authorize @actor, policy_class: Fedipub::Client::ActorPolicy
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
            format.json { render_serialized(Fedipub::Client::ActorResource, @actor) }
          end
        end
      end
    end
  end
end
