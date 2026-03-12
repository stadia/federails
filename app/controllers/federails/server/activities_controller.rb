require 'fediverse/inbox'

module Federails
  module Server
    class ActivitiesController < Federails::ServerController
      before_action :set_activity, only: [:show]

      # GET /federation/activities
      # GET /federation/actors/1/outbox.json
      def outbox
        authorize Federails::Activity, policy_class: Federails::Server::ActivityPolicy

        @actor            = Actor.find_param(params[:actor_id])
        @activities       = policy_scope(Federails::Activity, policy_scope_class: Federails::Server::ActivityPolicy::Scope).where(actor: @actor).order(created_at: :desc)
        @total_activities = @activities.count
        @activities       = @activities.page(params[:page])
      end

      # GET /federation/actors/1/activities/1.json
      def show; end

      # POST /federation/actors/1/inbox
      def create
        skip_authorization

        return head :unsupported_media_type unless supported_inbox_content_type?

        payload = payload_from_params
        return head :unprocessable_entity unless payload

        result = Fediverse::Inbox.dispatch_request(payload)
        Federails.logger.info { "[Inbox] dispatch_request result: #{result.inspect} for activity #{payload['id']}" }

        case result
        when true
          Fediverse::Inbox.maybe_forward(payload)
          head :created
        when :duplicate
          head :ok
        else
          head :unprocessable_entity
        end
      end

      private

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
