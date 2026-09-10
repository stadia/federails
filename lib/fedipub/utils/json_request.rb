require 'faraday'
require 'faraday/follow_redirects'
require 'fediverse/signature'

module Fedipub
  module Utils
    # Wrapper around HTTP calls which ensures signatures etc are applied.
    class JsonRequest
      include Singleton

      class << self
        extend Forwardable

        def_delegators :instance, :get_json, :get, :post
      end

      class UnhandledResponseStatus < StandardError; end

      # Makes a GET request and returns a +Hash+ from the parsed body
      #
      # @param url [String] Target URL
      # @param params [Hash] Querystring parameters
      # @param headers [Hash] Additional headers
      # @param expected_status [Integer] Expected response status. Will raise a +UnhandledResponseStatus+ when status is different
      #
      # @return The parsed JSON object
      #
      # @raise [UnhandledResponseStatus] when response status is not the expected_status
      def get_json(url, params: {}, headers: {}, expected_status: 200, from: nil)
        response = get url: url, params: params, headers: headers, from: from
        raise UnhandledResponseStatus, "Unhandled status code #{response.status} for GET #{url}" if expected_status && response.status != expected_status

        JSON.parse(response.body)
      end

      def get(url:, params: {}, headers: {}, from: nil)
        execute_request method: :get, url: url, params: params, headers: headers, from: from
      end

      def post(url:, message:, headers: {}, from: nil)
        execute_request method: :post, url: url, headers: headers, message: message, from: from
      end

      private

      # Send to remote server with RFC9421 signature and double-knocking for draft-cavage-12 if that fails
      def execute_request(method:, url:, params: {}, headers: {}, message: nil, from: nil) # rubocop:disable Metrics/ParameterLists
        req = build_request(method: method, url: url, params: params, headers: headers, message: message)
        response = connection.builder.build_response(
          connection,
          from ? Fediverse::Signature.sign(sender: from, request: req.dup) : req
        )
        # If signature was present and rejected, try double-knocking
        return response unless from && response.status.in?([400, 401])

        connection.builder.build_response(
          connection,
          Fediverse::Signature.sign(sender: from, request: req, legacy_signature: true)
        )
      end

      def build_request(method:, url:, params: {}, headers: {}, message: nil) # rubocop:todo Metrics/AbcSize
        # Extract params from URL string if they're in there instead of the hash
        params.merge! Rack::Utils.parse_nested_query(URI(url).query)
        # Build the request
        connection.build_request(method) do |req|
          req.url url
          req.body = message
          req.params = params
          req.headers = {
            'Content-Type' => Mime[:activitypub].to_s,
            'Accept'       => [Mime[:activitypub].to_s, Mime[:activitypub].send(:synonyms), "#{Mime[:json]};q=0.5"].flatten.join(', '),
            'User-Agent'   => req.headers['User-Agent'] || "Fedipub/#{Fedipub::VERSION}",
          }.compact.merge(headers)
        end
      end

      def connection
        @connection ||= Faraday.new do |faraday|
          faraday.response :follow_redirects
          faraday.adapter Faraday.default_adapter
        end
      end
    end
  end
end
