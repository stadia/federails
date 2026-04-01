# rbs_inline: enabled

require 'fediverse/inbox'

module Federails
  module Server
    class ActivitiesController < Federails::ServerController
      include Federails::Server::RenderCollections
      include Federails::Server::VerifySignature
      include Federails::Server::InboxPayload

      before_action :verify_http_signature!, only: :create
      before_action :set_activity, only: [:show]

      # GET /federation/activities
      # GET /federation/actors/1/outbox.json
      def outbox
        authorize Federails::Activity, policy_class: Federails::Server::ActivityPolicy

        actor      = Actor.find_param(params[:actor_id])
        activities = policy_scope(Federails::Activity, policy_scope_class: Federails::Server::ActivityPolicy::Scope).where(actor: actor).order(created_at: :desc)

        render_collection(
          collection: activities,
          actor:      actor,
          url_helper: :server_actor_outbox_url
        ) { |items| Federails::Server::ActivityResource.new(items, params: { context: false }).serializable_hash }
      end

      # GET /federation/actors/1/activities/1.json
      def show
        render_serialized(Federails::Server::ActivityResource, @activity, content_type: Mime[:activitypub])
      end

      # POST /federation/actors/1/inbox
      def create
        skip_authorization

        return head :unsupported_media_type unless supported_inbox_content_type?

        payload = payload_from_params
        return head Federails::Utils::ResponseCodes::UNPROCESSABLE_CONTENT unless payload

        log_social_activity_payload(payload)

        return head :unauthorized unless actor_match?(payload)

        result = Fediverse::Inbox.dispatch_request(payload)
        Federails.logger.info { "[Inbox] dispatch_request result: #{result.inspect} for activity #{payload['id']}" }

        case result
        when true
          Fediverse::Inbox.maybe_forward(payload)
          head :created
        when :duplicate
          head :ok
        else
          head Federails::Utils::ResponseCodes::UNPROCESSABLE_CONTENT
        end
      end

      private

      def verify_http_signature!
        return unless Federails::Configuration.verify_signatures

        @signed_actor = Fediverse::Signature.verify_request!(request)
      rescue Fediverse::Signature::SignatureVerificationError => e
        Federails.logger.warn "Signature verification failed: #{e.message}"
        head :unauthorized
      end

      # Use callbacks to share common setup or constraints between actions.
      def set_activity
        @activity = Actor.find_param(params[:actor_id]).activities.find_param(params[:id])
        authorize @activity, policy_class: Federails::Server::ActivityPolicy
      end

      # Only allow a list of trusted parameters through.
      def activity_params
        params.fetch(:activity, {})
      end

      def log_social_activity_payload(payload)
        type = payload['type']
        return unless type.in?(%w[Like Undo])

        Federails.logger.info do
          {
            message:      '[Inbox] social activity payload',
            type:         type,
            id:           payload['id'],
            actor:        payload['actor'],
            object:       payload['object'],
            signed_actor: @signed_actor&.federated_url,
            content_type: request.headers['Content-Type'],
          }.inspect
        end
      end
    end
  end
end
