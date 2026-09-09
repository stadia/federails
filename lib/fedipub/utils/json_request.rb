require 'faraday'
require 'faraday/follow_redirects'

module Fedipub
  module Utils
    # Simple wrapper to make requests expecting JSON
    module JsonRequest
      class UnhandledResponseStatus < StandardError; end

      BASE_HEADERS = {
        'Content-Type' => 'application/json',
        'Accept'       => 'application/json',
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

      def self.post(url:, message:, from: nil)
        conn = Faraday.default_connection
        conn.builder.build_response(
          conn,
          signed_request(url: url, message: message, from: from)
        )
      end

      def self.signed_request(url:, message:, from:)
        req = request(url: url, message: message)
        req = Fediverse::Signature.sign(sender: from, request: req) if from
        req
      end

      def self.request(url:, message:) # rubocop:todo Metrics/AbcSize
        Faraday.default_connection.build_request(:post) do |req|
          req.url url
          req.body = message
          req.headers['Content-Type'] = Mime[:activitypub].to_s
          req.headers['Accept'] = Mime[:activitypub].to_s
          req.headers['Host'] = URI.parse(url).host
          req.headers['Date'] = Time.now.utc.httpdate
        end
      end
    end
  end
end
