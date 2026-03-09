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
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      #: (String) -> Hash[String, untyped]?
      def dereference(value)
        return value if value.is_a? Hash
        return get(value) if value.is_a? String

        raise "Unhandled object type #{value.class}"
      end

      private

      #: (String) -> Hash[String, untyped]?
      def get(id)
        json = Federails::Utils::JsonRequest.get_json(id)

        JSON::LD::API.compact json, json['@context']
      rescue JSON::ParserError
        nil
      end
    end
  end
end
