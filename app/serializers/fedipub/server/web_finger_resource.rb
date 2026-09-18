# rbs_inline: enabled

module Fedipub
  module Server
    unless const_defined?(:WebFingerPayload)
      WebFingerPayload = Struct.new(
        :subject,            #: untyped
        :self_href,          #: untyped
        :profile_href,       #: untyped
        :remote_follow_url,  #: untyped
        :application_actor   #: untyped
      )
    end

    class WebFingerResource < BaseResource
      attributes :subject

      attribute :links do |payload|
        [
          self_link(payload),
          profile_link(payload),
          subscribe_link(payload),
          service_link(payload),
        ].compact
      end

      private

      def self_link(payload)
        { rel: 'self', type: Mime[:activitypub].to_s, href: payload.self_href }
      end

      def profile_link(payload)
        return unless payload.profile_href

        { rel: 'https://webfinger.net/rel/profile-page', type: 'text/html', href: payload.profile_href }
      end

      def subscribe_link(payload)
        return unless payload.remote_follow_url

        { rel: 'http://ostatus.org/schema/1.0/subscribe', template: "#{payload.remote_follow_url}?uri={uri}" }
      end

      def service_link(payload)
        return unless payload.application_actor

        { rel: 'https://www.w3.org/ns/activitystreams#Service', type: Mime[:activitypub].to_s, href: payload.self_href }
      end
    end
  end
end
