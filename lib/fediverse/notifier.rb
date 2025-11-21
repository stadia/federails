require 'fediverse/signature'

module Fediverse
  class Notifier
    class << self
      # Posts an activity to its recipients
      #
      # @param activity [Federails::Activity]
      def post_to_inboxes(activity)
        actors = activity.recipients
        Rails.logger.debug('Nobody to notice') && return if actors.none?

        message = payload(activity)
        actors.each do |recipient|
          Rails.logger.debug { "Sending activity ##{activity.id} to #{recipient.inbox_url}" }
          post_to_inbox(inbox_url: recipient.inbox_url, message: message, from: activity.actor)
        end
      end

      private

      def payload(activity)
        Federails::ServerController.renderer.new.render(
          template: 'federails/server/activities/show',
          assigns:  { activity: activity },
          format:   :json
        )
      end

      def post_to_inbox(inbox_url:, message:, from: nil)
        conn = Faraday.default_connection
        conn.builder.build_response(
          conn,
          signed_request(url: inbox_url, message: message, from: from)
        )
      end

      def signed_request(url:, message:, from:)
        req = request(url: url, message: message)
        req.headers['Signature'] = Fediverse::Signature.sign(sender: from, request: req) if from
        req
      end

      def request(url:, message:) # rubocop:todo Metrics/AbcSize
        Faraday.default_connection.build_request(:post) do |req|
          req.url url
          req.body = message
          req.headers['Content-Type'] = Mime[:activitypub].to_s
          req.headers['Accept'] = Mime[:activitypub].to_s
          req.headers['Host'] = URI.parse(url).host
          req.headers['Date'] = Time.now.utc.httpdate
          req.headers['Digest'] = digest(message)
        end
      end

      def digest(message)
        "SHA-256=#{Base64.strict_encode64(
          OpenSSL::Digest.new('SHA256').digest(message)
        )}"
      end
    end
  end
end
