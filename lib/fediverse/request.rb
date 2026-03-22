require 'json/ld'

module Fediverse
  class Request
    class << self
      # Dereferences a value
      #
      # @param value [String, Hash]
      #
      # @return [Hash, nil]
      def dereference(value)
        return value if value.is_a? Hash
        return get(value) if value.is_a? String

        raise "Unhandled object type #{value.class}"
      end

      private

      def get(id)
        json = Federails::Utils::JsonRequest.get_json(id)
        compact_json_ld(json)
      rescue JSON::ParserError, Federails::Utils::JsonRequest::UnhandledResponseStatus => e
        Federails.logger.warn { "Failed to dereference #{id}: #{e.message}" }
        nil
      end

      def compact_json_ld(json)
        JSON::LD::API.compact(json, json['@context'])
      rescue JSON::LD::JsonLdError => e
        Federails.logger.warn { "Unable to compact JSON-LD for #{json['id'] || 'unknown object'}: #{e.class} #{e.message}" }
        json
      end
    end
  end
end
