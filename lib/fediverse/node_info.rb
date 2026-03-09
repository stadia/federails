# rbs_inline: enabled

module Fediverse
  class NodeInfo
    class NotFoundError < StandardError; end
    class NoActivityPubError < StandardError; end

    class << self
      #: (String) -> Hash[Symbol, untyped]
      def fetch(domain)
        url = nodeinfo_url(domain)

        hash = Federails::Utils::JsonRequest.get_json url
        raise NoActivityPubError, "#{domain} does not handle activitypub protocol" unless hash['protocols'].include? 'activitypub'

        {
          domain:           domain,
          nodeinfo_url:     url,
          software_version: hash.dig('software', 'version'),
          software_name:    hash.dig('software', 'name'),
          protocols:        hash['protocols'],
          services:         hash['services'],
        }
      end

      private

      #: (String) -> String
      def base_url(domain)
        scheme = Federails::Configuration.force_ssl ? 'https' : 'http'
        @base_url = "#{scheme}://#{domain}"
      end

      #: (String) -> String
      def nodeinfo_url(domain)
        response = Federails::Utils::JsonRequest.get_json "#{base_url(domain)}/.well-known/nodeinfo", follow_redirects: true
        entry = response['links']&.find { |link| link['rel'] == 'http://nodeinfo.diaspora.software/ns/schema/2.0' }

        entry['href']
      end
    end
  end
end
