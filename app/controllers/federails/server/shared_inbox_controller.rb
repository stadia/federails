require 'fediverse/inbox'

module Federails
  module Server
    class SharedInboxController < Federails::ServerController
      include Federails::Server::VerifySignature

      skip_after_action :verify_authorized
      before_action :verify_http_signature!
      before_action :validate_content_type!

      # POST /federation/inbox
      def create
        payload = payload_from_params
        return head Federails::Utils::ResponseCodes::UNPROCESSABLE_CONTENT unless payload
        return head :unauthorized unless actor_match?(payload)

        result = Fediverse::Inbox.dispatch_request(payload)
        Federails.logger.info { "[SharedInbox] dispatch_request result: #{result.inspect} for activity #{payload['id']}" }

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

      def validate_content_type!
        head :unsupported_media_type unless supported_inbox_content_type?
      end

      def payload_from_params
        payload_string = request.body.read
        request.body.rewind if request.body.respond_to? :rewind

        begin
          payload = JSON.parse(payload_string)
        rescue JSON::ParserError => e
          Federails.logger.warn { "Failed to parse shared inbox payload: #{e.message}" }
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
        Federails.logger.warn { "Unable to compact shared inbox payload #{payload['id'] || '(no id)'}: #{e.class} #{e.message}" }
        payload
      end

      def supported_inbox_content_type?
        content_type = request.headers['Content-Type'].to_s
        content_type.start_with?('application/activity+json') ||
          (content_type.start_with?('application/ld+json') &&
            content_type.include?('https://www.w3.org/ns/activitystreams'))
      end
    end
  end
end
