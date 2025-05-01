require 'federails/utils/host'
require 'federails/utils/json_request'

module Fediverse
  # Methods related to Webfinger: find accounts, fetch actors,...
  class Webfinger
    class << self
      ACCOUNT_REGEX = /(?<username>[a-z0-9\-_.]+)(?:@(?<domain>.*))?/

      # Extracts username and domain from an account string.
      # Accepts forms "user@domain", "@user@domain" and "acct:user@domain"
      #
      # @param account [String] Account string
      #
      # @return [MatchData, nil] Matches with +:username+ and +:domain+ or +nil+
      def split_account(account)
        /\A(acct:|@)?#{ACCOUNT_REGEX}\z/io.match account
      end

      # Determines if a given account string should be a local account (same host as configured one)
      #
      # @param hash [Hash, MatchData] Object with +:username+ and +:domain+ keys
      #
      # @return [Boolean]
      def local_user?(hash)
        hash[:username] && (hash[:domain].nil? || (hash[:domain] == Federails::Utils::Host.localhost))
      end

      # Fetches a distant actor
      #
      # @param username [String]
      # @param domain [String]
      #
      # @return [Federails::Actor, nil] Federails actor or nothing when not found
      def fetch_actor(username, domain)
        fetch_actor_url webfinger(username, domain)
      end

      # Fetches an actor given its URL
      #
      # @param url [String] Actor's federation URL
      #
      # @return [Federails::Actor, nil] Federails actor or nothing when not found
      def fetch_actor_url(url)
        webfinger_to_actor get_json url
      end

      # Gets the real actor's federation URL from its username and domain
      #
      # @param username [String]
      # @param domain [String]
      #
      # @return [String, nil] Federation URL if found
      def webfinger(username, domain)
        json = webfinger_response(username, domain)
        link = json['links'].find { |l| Mime::Type.lookup(l['type']).to_sym == :activitypub }

        link['href'] if link
      end

      # Returns remote follow link template, or complete link if actor_url is provided
      #
      # @param username [String]
      # @param domain [String]
      # @param actor_url [String] Optional Federation URL to provide when known
      #
      # @return [String] The URL to use as follow URL
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

      # Makes a webfinger request for a given username/domain
      # @return [Hash] Webfinger response's content
      def webfinger_response(username, domain)
        scheme = Federails.configuration.force_ssl ? 'https' : 'http'
        get_json "#{scheme}://#{domain}/.well-known/webfinger", resource: "acct:#{username}@#{domain}"
      end

      # Extracts the server and port from a string, omitting common ports
      # @return [String] Server and port
      def server_and_port(string)
        uri = URI.parse string
        if uri.port && [80, 443].exclude?(uri.port)
          "#{uri.host}:#{uri.port}"
        else
          uri.host
        end
      end

      # Builds a +Federails::Actor+ from a Webfinger response
      # @param data [Hash] Webfinger response
      # @return [Federails::Actor]
      def webfinger_to_actor(data) # rubocop:disable Metrics/MethodLength
        data = data.clone
        id = data.delete('id')
        Federails::Actor.new federated_url:  id,
                             username:       data.delete('preferredUsername'),
                             actor_type:     data.delete('type'),
                             name:           data.delete('name'),
                             server:         server_and_port(id),
                             inbox_url:      data.delete('inbox'),
                             outbox_url:     data.delete('outbox'),
                             followers_url:  data.delete('followers'),
                             followings_url: data.delete('following'),
                             profile_url:    data.delete('url'),
                             public_key:     data.delete('publicKey')&.dig('publicKeyPem'),
                             extensions:     data.except('@context')
      end

      # Makes a simple GET request and returns a +Hash+ from the parsed body
      # @return [Hash]
      # @raise [ActiveRecord::RecordNotFound] when the response is invalid
      def get_json(url, params = {})
        Federails::Utils::JsonRequest.get_json(url, params: params, follow_redirects: true, headers: { accept: 'application/json' })
      rescue Federails::Utils::JsonRequest::UnhandledResponseStatus => e
        Rails.logger.debug { e.message }

        raise ActiveRecord::RecordNotFound
      rescue Faraday::ConnectionFailed
        Rails.logger.debug { "Failed to reach server for GET #{url}" }

        raise ActiveRecord::RecordNotFound
      rescue JSON::ParserError
        Rails.logger.debug { "Invalid JSON response for GET #{url}" }

        raise ActiveRecord::RecordNotFound
      end
    end
  end
end
