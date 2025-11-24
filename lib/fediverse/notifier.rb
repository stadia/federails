require 'fediverse/signature'

module Fediverse
  class Notifier
    class << self
      # Posts an activity to its recipients
      #
      # @param activity [Federails::Activity]
      def post_to_inboxes(activity)
        # Get the list of actors we need to send the activity to
        inboxes = inboxes_for(activity)
        Rails.logger.debug('Nobody to notice') && return if inboxes.none?

        # Deliver to each inbox
        message = payload(activity)
        inboxes.each do |url|
          Rails.logger.debug { "Sending activity ##{activity.id} to inbox at #{url}" }
          post_to_inbox(inbox_url: url, message: message, from: activity.actor)
        end
      end

      private

      # Determines the list of inboxes that the activity should be delivered to
      #
      # @return [Array<Federails::Actor>]
      def inboxes_for(activity)
        return [] unless activity.actor.local?

        [activity.to, activity.cc].flatten.compact.map do |url|
          if (actor = Federails::Actor.find_by_federation_url(url))
            [actor.inbox_url]
          else
            [] # Collection
          end
        end.flatten
      end

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
