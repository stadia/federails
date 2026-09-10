require 'faraday'
require 'faraday/follow_redirects'
require 'fediverse/signature'

module Fedipub
  module Utils
    # Simple wrapper to make requests expecting JSON
    module JsonRequest
      class UnhandledResponseStatus < StandardError; end

      BASE_HEADERS = {
        'Content-Type' => 'application/ld+json;profile="https://www.w3.org/ns/activitystreams"',
        'Accept'       => 'application/ld+json;profile="https://www.w3.org/ns/activitystreams", application/activity+json, application/json;q=0.5',
        'User-Agent'   => "Fedipub/#{Fedipub::VERSION}",
      }.freeze

      # Makes a GET request and returns a +Hash+ from the parsed body
      #
      # @param url [String] Target URL
      # @param params [Hash] Querystring parameters
      # @param headers [Hash] Additional headers
      # @param follow_redirects [Boolean] Whether to follow redirections
      # @param expected_status [Integer] Expected response status. Will raise a +UnhandledResponseStatus+ when status is different
      #
      # @return The parsed JSON object
      #
      # @raise [UnhandledResponseStatus] when response status is not the expected_status
      def self.get_json(url, params: {}, headers: {}, follow_redirects: false, expected_status: 200)
        headers = BASE_HEADERS.merge headers

        connection = Faraday.new url: url, params: params, headers: headers do |faraday|
          faraday.response :follow_redirects if follow_redirects
          faraday.adapter Faraday.default_adapter
        end

        response = connection.get
        raise UnhandledResponseStatus, "Unhandled status code #{response.status} for GET #{url}" if expected_status && response.status != expected_status

        JSON.parse(response.body)
      end

      def self.get(url:, params: {}, headers: {}, from: nil, connection: Faraday.default_connection)
        execute_request method: :get, url: url, params: params, headers: headers, from: from, connection: connection
      end

      def self.post(url:, params: {}, headers: {}, message:, from: nil, connection: Faraday.default_connection)
        execute_request method: :post, url: url, params: params, headers: headers, message: message, from: from, connection: connection
      end

      # Send to remote server with RFC9421 signature and double-knocking for draft-cavage-12 if that fails
      def self.execute_request(method:, url:, params: {}, headers: {}, message: nil, from: nil, connection: Faraday.default_connection)
        req = build_request(method: method, url: url, params: params, headers: headers, message: message, connection: connection)
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

      def self.build_request(method:, url:, params: {}, headers: {}, message: nil, connection: Faraday.default_connection) # rubocop:todo Metrics/AbcSize
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
    end
  end
end
