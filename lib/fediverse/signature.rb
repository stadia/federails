# rbs_inline: enabled

module Fediverse
  class Signature
    class SignatureVerificationError < StandardError; end

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

      # Parse an HTTP Signature header into its components
      #: (String) -> { key_id: String, headers: String, signature: String, algorithm: String? }
      def parse_signature_header(header)
        raise SignatureVerificationError, 'Missing Signature header' if header.blank?

        params = header.scan(/(\w+)="((?:[^"\\]|\\.)*)"/).to_h.transform_values { |v| v.gsub('\\"', '"') }
        key_id    = params['keyId']
        headers   = params['headers']
        signature = params['signature']

        raise SignatureVerificationError, 'Malformed Signature header: missing keyId' if key_id.blank?
        raise SignatureVerificationError, 'Malformed Signature header: missing signature' if signature.blank?
        raise SignatureVerificationError, 'Malformed Signature header: missing headers' if headers.blank?

        { key_id: key_id, headers: headers, signature: signature, algorithm: params['algorithm'] }
      end

      # Verify the Digest header matches the request body
      #: (untyped) -> void
      def verify_digest!(request)
        digest_header = request.headers['Digest']
        raise SignatureVerificationError, 'Missing Digest header' if digest_header.blank?

        body = request.body.read
        request.body.rewind

        expected = "SHA-256=#{Base64.strict_encode64(OpenSSL::Digest.new('SHA256').digest(body))}"

        return if ActiveSupport::SecurityUtils.secure_compare(digest_header, expected)

        raise SignatureVerificationError, 'Digest mismatch'
      end

      # Verify an inbound request's HTTP Signature, returning the sending actor
      #: (untyped) -> Federails::Actor
      def verify_request!(request)
        parsed = parse_signature_header(request.headers['Signature'])

        verify_digest!(request)

        actor_uri = parsed[:key_id].sub(/#.*\z/, '')
        actor = begin
          Federails::Actor.find_or_create_by_federation_url(actor_uri)
        rescue StandardError => e
          raise SignatureVerificationError, "Unable to load signed actor: #{e.message}"
        end

        comparison_string = signature_payload(request: request, headers: parsed[:headers])
        raw_signature = Base64.decode64(parsed[:signature])
        key = OpenSSL::PKey::RSA.new(actor.public_key)
        digest = OpenSSL::Digest.new('SHA256')

        return actor if key.verify(digest, raw_signature, comparison_string)

        # Key rotation retry: only re-fetch if the cached actor is stale
        if actor.updated_at < Federails::Configuration.remote_entities_cache_duration.ago
          begin
            actor.sync!
          rescue StandardError => e
            raise SignatureVerificationError, "Unable to refresh signed actor: #{e.message}"
          end

          key = OpenSSL::PKey::RSA.new(actor.public_key)
          return actor if key.verify(digest, raw_signature, comparison_string)
        end

        raise SignatureVerificationError, 'Signature verification failed'
      end

      private

      #: (request: untyped, headers: String) -> String
      def signature_payload(request:, headers:)
        headers.split.map do |signed_header_name|
          if signed_header_name == '(request-target)'
            "(request-target): #{(request.try(:http_method) || request.request_method).downcase} #{URI.parse(request.path).path}"
          else
            "#{signed_header_name}: #{request.headers[signed_header_name.capitalize]}"
          end
        end.join("\n")
      end
    end
  end
end
