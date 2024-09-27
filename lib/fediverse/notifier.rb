module Fediverse
  class Notifier
    class << self
      def post_to_inbox(message, inbox_url)
        Faraday.post(
          inbox_url,
          message,
          'Content-Type' => Mime[:activitypub].to_s,
          'Accept'       => Mime[:activitypub].to_s
        )
      end

      def post_to_inboxes(activity)
        actors = activity.recipients

        Rails.logger.debug('Nobody to notice') && return if actors.count.zero?

        message = Federails::ApplicationController.renderer.new.render(
          template: 'federails/server/activities/show',
          assigns:  { activity: activity },
          format:   :json
        )
        actors.each do |actor|
          Rails.logger.debug { "Sending activity ##{activity.id} to #{actor.inbox_url}" }
          post_to_inbox(message, actor.inbox_url)
        end
      end
    end
  end
end
