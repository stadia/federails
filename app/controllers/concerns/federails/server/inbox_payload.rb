module Federails
  module Server
    module InboxPayload
      extend ActiveSupport::Concern

      private

      def payload_from_params
        payload_string = request.body.read
        request.body.rewind if request.body.respond_to? :rewind

        begin
          payload = JSON.parse(payload_string)
        rescue JSON::ParserError => e
          Federails.logger.warn { "Failed to parse inbox payload: #{e.message}" }
          return
        end

        hash = compact_payload(payload)
        validate_payload hash
      end

      def validate_payload(hash)
        return unless hash['@context'] && hash['id'] && hash['type'] && hash['actor'] && hash['object']

        hash
      end

      def compact_payload(payload)
        JSON::LD::API.compact(payload, payload['@context'])
      rescue JSON::LD::JsonLdError => e
        Federails.logger.warn { "Unable to compact inbox payload #{payload['id'] || '(no id)'}: #{e.class} #{e.message}" }
        payload
      end

      def supported_inbox_content_type?
        content_type = request.headers['Content-Type'].to_s
        return true if content_type.start_with?('application/activity+json')
        return false unless content_type.start_with?('application/ld+json')

        content_type.include?('https://www.w3.org/ns/activitystreams')
      end
    end
  end
end
