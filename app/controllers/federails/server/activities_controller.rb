require 'fediverse/inbox'

module Federails
  module Server
    class ActivitiesController < Federails::ServerController
      include Federails::Server::RenderCollections

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

        if Federails::Configuration.verify_signatures && @signed_actor
          payload_actor_url = payload['actor'].is_a?(String) ? payload['actor'] : payload.dig('actor', 'id')
          unless @signed_actor.federated_url == payload_actor_url
            Federails.logger.warn "Signature actor mismatch: signed=#{@signed_actor.federated_url} payload=#{payload_actor_url}"
            return head :unauthorized
          end
        end

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

      def payload_from_params
        payload_string = request.body.read
        request.body.rewind if request.body.respond_to? :rewind

        begin
          payload = JSON.parse(payload_string)
        rescue JSON::ParserError
          return
        end

        hash = compact_payload(payload)
        validate_payload hash
      end

      def validate_payload(hash)
        return unless hash['@context'] && hash['id'] && hash['type'] && hash['actor'] && hash['object']

        hash
      end

      def compact_payload(payload)
        JSON::LD::API.compact(payload, payload['@context'])
      rescue JSON::LD::JsonLdError => e
        Federails.logger.warn { "Unable to compact inbox payload #{payload['id'] || '(no id)'}: #{e.class} #{e.message}" }
        payload
      end

      def supported_inbox_content_type?
        # NOTE: request.media_type returns the registered primary type (application/ld+json; profile="...")
        # even when the actual Content-Type header is application/activity+json (a registered alias).
        # So we must check the raw header directly.
        content_type = request.headers['Content-Type'].to_s
        return true if content_type.start_with?('application/activity+json')
        return false unless content_type.start_with?('application/ld+json')

        content_type.include?('https://www.w3.org/ns/activitystreams')
      end
    end
  end
end
