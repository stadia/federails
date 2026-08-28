# rbs_inline: enabled

require 'fediverse/inbox'

module Fedipub
  module Server
    class SharedInboxController < Fedipub::ServerController
      include Fedipub::Server::VerifySignature
      include Fedipub::Server::InboxPayload

      skip_after_action :verify_authorized
      before_action :verify_http_signature!
      before_action :validate_content_type!

      # POST /federation/inbox
      def create
        payload = payload_from_params
        return head Fedipub::Utils::ResponseCodes::UNPROCESSABLE_CONTENT unless payload
        return head :unauthorized unless actor_match?(payload)

        result = Fediverse::Inbox.dispatch_request(payload)
        Fedipub.logger.info { "[SharedInbox] dispatch_request result: #{result.inspect} for activity #{payload['id']}" }

        case result
        when true
          Fediverse::Inbox.maybe_forward(payload)
          head :created
        when :duplicate
          head :ok
        else
          head Fedipub::Utils::ResponseCodes::UNPROCESSABLE_CONTENT
        end
      end

      private

      def validate_content_type!
        head :unsupported_media_type unless supported_inbox_content_type?
      end
    end
  end
end
