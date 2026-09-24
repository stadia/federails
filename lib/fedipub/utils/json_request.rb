# typed: true
# rbs_inline: enabled

require 'faraday'
require 'fediverse/signature'

module Fedipub
  module Utils
    # Wrapper around HTTP calls which ensures signatures etc are applied.
    class JsonRequest
      include Singleton

      # @rbs @connection: Faraday::Connection

      MAX_REDIRECTS = 5
      REDIRECT_STATUSES = [301, 302, 303, 307, 308].freeze

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
      # @param expected_status [Integer, nil] Expected response status. Will raise a +UnhandledResponseStatus+ when status is different; +nil+ disables the check
      # @param from [Fedipub::Actor, nil] Actor signing the request; defaults to the application actor
      #
      # @return [Hash, Array] The parsed JSON object
      #
      # @raise [UnhandledResponseStatus] when response status is not the expected_status
      def get_json(url, params: {}, headers: {}, expected_status: 200, from: nil)
        response = get url: url, params: params, headers: headers, from: from
        raise UnhandledResponseStatus, "Unhandled status code #{response.status} for GET #{url}" if expected_status && response.status != expected_status

        JSON.parse(response.body)
      end

      # Makes a GET request signed by +from+ (the application actor by default), following redirects
      def get(url:, params: {}, headers: {}, from: nil)
        execute_request method: :get, url: url, params: params, headers: headers, from: from || Fedipub::Actor.application_actor
      end

      # Makes a POST request, signed by +from+ when given. Redirects are not followed.
      def post(url:, message:, headers: {}, from: nil)
        execute_request method: :post, url: url, headers: headers, message: message, from: from
      end

      private

      # Follows redirects for GETs only, signing the request again for each new target: signatures cover the target URI.
      # POSTs are not redirected, so an activity is never replayed to a target we did not choose.
      def execute_request(method:, url:, params: {}, headers: {}, message: nil, from: nil)
        redirects = 0
        loop do
          response = send_request(method: method, url: url, params: params, headers: headers, message: message, from: from)
          return response unless method == :get && REDIRECT_STATUSES.include?(response.status)

          location = response.headers['Location']
          return response if location.blank? || redirects >= MAX_REDIRECTS

          redirects += 1
          url = URI.join(url, location).to_s
          params = {}
        end
      end

      # Sends with an RFC9421 signature, then retries once with a draft-cavage-12 signature (double-knocking)
      # on a freshly built request if we signed and got a 400 or 401.
      def send_request(method:, url:, params:, headers:, message:, from:) # rubocop:todo Metrics/AbcSize
        build = -> { build_request(method: method, url: url, params: params, headers: headers, message: message) }
        response = connection.builder.build_response(connection, from ? Fediverse::Signature.sign(sender: from, request: build.call) : build.call)
        return response unless from && response.status.in?([400, 401])

        Fedipub.logger.debug { "#{method.upcase} #{url} got #{response.status} with an RFC9421 signature, retrying with draft-cavage-12" }
        connection.builder.build_response(connection, Fediverse::Signature.sign(sender: from, request: build.call, legacy_signature: true))
      end

      def build_request(method:, url:, params: {}, headers: {}, message: nil) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        # Extract params from URL string if they're in there instead of the hash
        uri = URI(url)
        params = params.merge Rack::Utils.parse_nested_query(uri.query)
        uri.query = nil
        # Build the request
        connection.build_request(method) do |req|
          req.url uri
          req.body = message
          req.params = params
          req.headers = {
            'Content-Type'     => Mime[:activitypub].to_s,
            'Accept'           => [Mime[:activitypub].to_s, Mime[:activitypub].send(:synonyms), "#{Mime[:json]};q=0.5"].flatten.join(', '),
            'User-Agent'       => req.headers['User-Agent'] || "Fedipub/#{Fedipub::VERSION}",
            'Accept-Signature' => 'sig1=()',
          }.compact.merge(headers)
        end
      end

      def connection
        @connection ||= Faraday.new do |faraday|
          faraday.adapter Faraday.default_adapter
        end
      end
    end
  end
end
