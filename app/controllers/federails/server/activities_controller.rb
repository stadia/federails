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

        Rails.logger.info { "[Inbox] Content-Type: #{request.headers['Content-Type'].inspect}, media_type: #{request.media_type.inspect}, media_type_params: #{request.media_type_params.inspect}" }

        unless supported_inbox_content_type?
          Rails.logger.info { "[Inbox] Rejected: unsupported media type (Content-Type: #{request.headers['Content-Type'].inspect})" }
          return head :unsupported_media_type
        end

        payload = payload_from_params
        unless payload
          Rails.logger.info { '[Inbox] Rejected: invalid or missing payload fields' }
          return head :unprocessable_entity
        end

        result = Fediverse::Inbox.dispatch_request(payload)
        Rails.logger.info { "[Inbox] dispatch_request result: #{result.inspect} for activity #{payload['id']}" }

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
        Rails.logger.warn { "Unable to compact inbox payload #{payload['id'] || '(no id)'}: #{e.class} #{e.message}" }
        payload
      end

      def supported_inbox_content_type?
        return true if request.media_type == 'application/activity+json'
        return false unless request.media_type == 'application/ld+json'

        content_type = request.headers['Content-Type'].to_s
        content_type.include?('https://www.w3.org/ns/activitystreams') ||
          request.media_type_params['profile'] == 'https://www.w3.org/ns/activitystreams'
      end
    end
  end
end
