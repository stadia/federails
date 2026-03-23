# rbs_inline: enabled

module Fediverse
  class Signature
    class << self
      #: (sender: Federails::Actor, request: untyped) -> String
      def sign(sender:, request:)
        private_key = OpenSSL::PKey::RSA.new sender.private_key, Rails.application.credentials.secret_key_base
        headers = '(request-target) host date digest'
        sig = Base64.strict_encode64(
          private_key.sign(
            OpenSSL::Digest.new('SHA256'), signature_payload(request: request, headers: headers)
          )
        )
        {
          keyId:     sender.key_id,
          headers:   headers,
          signature: sig,
        }.map { |k, v| "#{k}=\"#{v}\"" }.join(',')
      end

      # Performs a signed GET request on behalf of a local actor
      #
      # @param url [String] Target URL
      # @param actor [Federails::Actor] Local actor to sign as
      # @return [Hash, nil] Parsed JSON response or nil on failure
      def signed_get(url, actor:)
        uri = URI.parse(url)
        body = ''

        req = Faraday.default_connection.build_request(:get) do |r|
          r.url url
          r.body = body
          r.headers['Accept'] = 'application/activity+json'
          r.headers['Host'] = uri.host
          r.headers['Date'] = Time.now.utc.httpdate
          r.headers['Digest'] = "SHA-256=#{Base64.strict_encode64(OpenSSL::Digest.new('SHA256').digest(body))}"
        end

        req.headers['Signature'] = sign(sender: actor, request: req)

        response = Faraday.get(url) do |r|
          req.headers.each { |k, v| r.headers[k] = v }
        end

        unless response.status == 200
          raise Federails::Utils::JsonRequest::UnhandledResponseStatus,
                "Unhandled status code #{response.status} for signed GET #{url}"
        end

        JSON.parse(response.body)
      end

      #: (sender: Federails::Actor, request: untyped) -> bool
      def verify(sender:, request:)
        raise 'Unsigned headers' unless request.headers['Signature']

        signature_header = request.headers['Signature'].split(',').to_h do |pair|
          /\A(?<key>\w+)="(?<value>.*)"\z/ =~ pair
          [key, value]
        end

        headers   = signature_header['headers']
        signature = Base64.decode64(signature_header['signature'])
        key       = OpenSSL::PKey::RSA.new(sender.public_key)

        comparison_string = signature_payload(request: request, headers: headers)

        key.verify(OpenSSL::Digest.new('SHA256'), signature, comparison_string)
      end

      private

      #: (request: untyped, headers: String) -> String
      def signature_payload(request:, headers:)
        headers.split.map do |signed_header_name|
          if signed_header_name == '(request-target)'
            "(request-target): #{request.http_method} #{URI.parse(request.path).path}"
          else
            "#{signed_header_name}: #{request.headers[signed_header_name.capitalize]}"
          end
        end.join("\n")
      end
    end
  end
end
