# rbs_inline: enabled

module Fedipub
  module Server
    unless const_defined?(:WebFingerPayload)
      WebFingerPayload = Struct.new(
        :subject,           #: untyped
        :self_href,         #: untyped
        :profile_href,      #: untyped
        :remote_follow_url  #: untyped
      )
    end

    class WebFingerResource < BaseResource
      attributes :subject

      attribute :links do |payload|
        links = [
          {
            rel:  'self',
            type: Mime[:activitypub].to_s,
            href: payload.self_href,
          },
        ]

        if payload.profile_href
          links << {
            rel:  'https://webfinger.net/rel/profile-page',
            type: 'text/html',
            href: payload.profile_href,
          }
        end

        if payload.remote_follow_url
          links << {
            rel:      'http://ostatus.org/schema/1.0/subscribe',
            template: "#{payload.remote_follow_url}?uri={uri}",
          }
        end

        links
      end
    end
  end
end
