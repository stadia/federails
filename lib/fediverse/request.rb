# typed: true
# rbs_inline: enabled

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

      #: (String) -> Hash[String, untyped]?
      def get(id)
        json = Fedipub::Utils::JsonRequest.get_json(id)
        compact_json_ld(json)
      rescue JSON::ParserError, Fedipub::Utils::JsonRequest::UnhandledResponseStatus => e
        Fedipub.logger.warn { "Failed to dereference #{id}: #{e.message}" }
        nil
      end

      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def compact_json_ld(json)
        JSON::LD::API.compact(json, json['@context'])
      rescue JSON::LD::JsonLdError => e
        Fedipub.logger.warn { "Unable to compact JSON-LD for #{json['id'] || 'unknown object'}: #{e.class} #{e.message}" }
        json
      end
    end
  end
end
