# rbs_inline: enabled

module Fediverse
  class NodeInfo
    class NotFoundError < StandardError; end
    class NoActivityPubError < StandardError; end
    NODEINFO_SCHEMA_RELS = [
      'http://nodeinfo.diaspora.software/ns/schema/2.1',
      'http://nodeinfo.diaspora.software/ns/schema/2.0',
    ].freeze #: Array[String]

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
        entry = NODEINFO_SCHEMA_RELS.lazy.map { |rel| response['links']&.find { |link| link['rel'] == rel } }.find(&:itself)

        entry['href']
      end
    end
  end
end
