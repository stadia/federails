require 'faraday'
require 'faraday/follow_redirects'

module Federails
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
    end
  end
end
