require 'fediverse/inbox'

module Federails
  module Server
    class SharedInboxController < Federails::ServerController
      include Federails::Server::VerifySignature
      include Federails::Server::InboxPayload

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
    end
  end
end
