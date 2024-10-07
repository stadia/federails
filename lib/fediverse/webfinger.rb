require 'faraday'
require 'faraday/follow_redirects'

require 'federails/utils/host'

module Fediverse
  class Webfinger
    class << self
      ACCOUNT_REGEX = /(?<username>[a-z0-9\-_.]+)(?:@(?<domain>.*))?/

      def split_resource_account(account)
        /\Aacct:#{ACCOUNT_REGEX}\z/io.match account
      end

      def split_account(account)
        /\A#{ACCOUNT_REGEX}\z/io.match account
      end

      def local_user?(account)
        account[:username] && (account[:domain].nil? || (account[:domain] == Federails::Utils::Host.localhost))
      end

      def fetch_actor(username, domain)
        fetch_actor_url webfinger(username, domain)
      end

      def fetch_actor_url(url)
        webfinger_to_actor get_json url
      end

      # Returns actor id
      def webfinger(username, domain)
        json = webfinger_response(username, domain)
        link = json['links'].find { |l| l['type'] == 'application/activity+json' }

        link['href'] if link
      end

      # Returns remote follow link template, or complete link if actor_url is provided
      def remote_follow_url(username, domain, actor_url: nil)
        json = webfinger_response(username, domain)
        link = json['links'].find { |l| l['rel'] == 'http://ostatus.org/schema/1.0/subscribe' }
        return nil if link&.dig('template').nil?

        if actor_url
          link['template'].gsub('{uri}', CGI.escape(actor_url))
        else
          link['template']
        end
      end

      private

      def webfinger_response(username, domain)
        scheme = Federails.configuration.force_ssl ? 'https' : 'http'
        get_json "#{scheme}://#{domain}/.well-known/webfinger", resource: "acct:#{username}@#{domain}"
      end

      def server_and_port(id)
        uri = URI.parse id
        if uri.port && [80, 443].exclude?(uri.port)
          "#{uri.host}:#{uri.port}"
        else
          uri.host
        end
      end

      def webfinger_to_actor(data)
        Federails::Actor.new federated_url:  data['id'],
                             username:       data['preferredUsername'],
                             name:           data['name'],
                             server:         server_and_port(data['id']),
                             inbox_url:      data['inbox'],
                             outbox_url:     data['outbox'],
                             followers_url:  data['followers'],
                             followings_url: data['following'],
                             profile_url:    data['url'],
                             public_key:     data.dig('publicKey', 'publicKeyPem')
      end

      def get_json(url, payload = {})
        response = get(url, payload: payload, headers: { accept: 'application/json' })

        if response.status != 200
          Rails.logger.debug { "Unhandled status code #{response.status} for GET #{url}" }
          raise ActiveRecord::RecordNotFound
        end

        JSON.parse(response.body)
      rescue JSON::ParserError
        Rails.logger.debug { "Invalid JSON response GET #{url}" }

        raise ActiveRecord::RecordNotFound
      end

      # Only perform a GET request and throws an ActiveRecord::RecordNotFound
      # on error.
      # That's "ok-ish"; when an actor is unavailable, whatever the reason is, it's
      # not found...
      def get(url, payload: {}, headers: {})
        connection = Faraday.new url: url, params: payload, headers: headers do |faraday|
          faraday.response :follow_redirects # use Faraday::FollowRedirects::Middleware
          faraday.adapter Faraday.default_adapter
        end

        begin
          response = connection.get
        rescue Faraday::ConnectionFailed
          Rails.logger.debug { "Failed to reach server for GET #{url}" }
          raise ActiveRecord::RecordNotFound
        end

        response
      end
    end
  end
end
