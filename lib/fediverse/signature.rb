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

      # Parse an HTTP Signature header (cavage draft format) into its components
      #: (String) -> { key_id: String, headers: String, signature: String, algorithm: String? }
      def parse_signature_header(header)
        raise SignatureVerificationError, 'Missing Signature header' if header.blank?

        params = header.scan(/(\w+)="((?:[^"\\]|\\.)*)"/).to_h.transform_values { |v| v.gsub('\\"', '"') }
        key_id    = params['keyId']
        headers   = params['headers']
        signature = params['signature']

        if key_id.blank?
          Federails.logger.warn { "[Signature] Raw header (missing keyId): #{header.inspect}" }
          raise SignatureVerificationError, 'Malformed Signature header: missing keyId'
        end
        raise SignatureVerificationError, 'Malformed Signature header: missing signature' if signature.blank?
        raise SignatureVerificationError, 'Malformed Signature header: missing headers' if headers.blank?

        { key_id: key_id, headers: headers, signature: signature, algorithm: params['algorithm'] }
      end

      # Verify the Digest header matches the request body (cavage draft format)
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

      # Verify an inbound request's HTTP Signature, returning the sending actor.
      # Supports both cavage draft and RFC 9421 formats.
      #: (untyped) -> Federails::Actor
      def verify_request!(request)
        sig_header = request.headers['Signature']
        raise SignatureVerificationError, 'Missing Signature header' if sig_header.blank?

        if rfc9421_format?(sig_header)
          verify_rfc9421_request!(request)
        else
          verify_cavage_request!(request)
        end
      end

      private

      # RFC 9421 uses label=:bytes: format; cavage uses keyId="..." format
      def rfc9421_format?(sig_header)
        sig_header.match?(/\A\w+=:/)
      end

      def verify_cavage_request!(request)
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

      def verify_rfc9421_request!(request)
        parsed = parse_rfc9421_headers(request.headers['Signature'], request.headers['Signature-Input'])

        actor_uri = parsed[:key_id].sub(/#.*\z/, '')
        actor = begin
          Federails::Actor.find_or_create_by_federation_url(actor_uri)
        rescue StandardError => e
          raise SignatureVerificationError, "Unable to load signed actor: #{e.message}"
        end

        base = rfc9421_signature_base(request, parsed[:components], parsed[:input_params])
        key  = OpenSSL::PKey::RSA.new(actor.public_key)

        return actor if rfc9421_verify(key, parsed[:signature], base, parsed[:algorithm])

        if actor.updated_at < Federails::Configuration.remote_entities_cache_duration.ago
          begin
            actor.sync!
          rescue StandardError => e
            raise SignatureVerificationError, "Unable to refresh signed actor: #{e.message}"
          end

          key = OpenSSL::PKey::RSA.new(actor.public_key)
          return actor if rfc9421_verify(key, parsed[:signature], base, parsed[:algorithm])
        end

        raise SignatureVerificationError, 'Signature verification failed'
      end

      # Parse RFC 9421 Signature + Signature-Input headers.
      # Signature:       sig1=:base64bytes:
      # Signature-Input: sig1=("@method" "@path");keyid="...";alg="rsa-pss-sha512"
      def parse_rfc9421_headers(sig_header, sig_input_header)
        raise SignatureVerificationError, 'Missing Signature-Input header' if sig_input_header.blank?

        # Extract label → raw base64 from Signature header
        sigs = sig_header.scan(/(\w+)=:([A-Za-z0-9+\/=]*):\s*/).to_h
        raise SignatureVerificationError, 'No valid signatures in Signature header' if sigs.empty?

        label = sigs.keys.first
        raw_b64 = sigs[label]

        # Extract input params for this label from Signature-Input
        # Format: label=(components);param=value;param=value
        input_params = sig_input_header
          .split(/,(?=\s*\w+=\()/)
          .map(&:strip)
          .find { |s| s.start_with?("#{label}=") }
          &.sub(/\A#{Regexp.escape(label)}=/, '')

        raise SignatureVerificationError, "Missing Signature-Input for label '#{label}'" if input_params.blank?

        components_match = input_params.match(/\A\((.*?)\)/)
        raise SignatureVerificationError, 'Malformed Signature-Input: missing component list' unless components_match

        components = components_match[1].scan(/"([^"]+)"/).flatten
        key_id     = input_params.match(/;keyid="([^"]+)"/)&.captures&.first
        algorithm  = input_params.match(/;alg="([^"]+)"/)&.captures&.first

        raise SignatureVerificationError, 'Malformed Signature-Input: missing keyid' if key_id.blank?

        {
          label:        label,
          key_id:       key_id,
          components:   components,
          signature:    Base64.decode64(raw_b64),
          algorithm:    algorithm,
          input_params: input_params,
        }
      end

      # Build the RFC 9421 signature base string from request and covered components.
      def rfc9421_signature_base(request, components, input_params)
        lines = components.map do |component|
          value = case component
                  when '@method'         then request.method
                  when '@path'           then URI.parse(request.url).path
                  when '@authority'      then request.host + (request.standard_port? ? '' : ":#{request.port}")
                  when '@target-uri'     then request.url
                  when '@scheme'         then request.scheme
                  when '@request-target' then "#{request.method.downcase} #{URI.parse(request.url).path}"
                  else                   request.headers[component] || request.headers[component.split('-').map(&:capitalize).join('-')]
                  end
          "\"#{component}\": #{value}"
        end

        lines << "\"@signature-params\": #{input_params}"
        lines.join("\n")
      end

      # Verify an RFC 9421 signature. Tries appropriate algorithm and falls back to RSA-SHA256.
      def rfc9421_verify(key, signature, base, algorithm)
        case algorithm
        when 'rsa-pss-sha512'
          key.verify_pss('SHA512', signature, base, salt_length: :auto, mgf1_hash: 'SHA512')
        when 'rsa-pss-sha256'
          key.verify_pss('SHA256', signature, base, salt_length: :auto, mgf1_hash: 'SHA256')
        when 'rsa-v1_5-sha256', nil
          key.verify(OpenSSL::Digest.new('SHA256'), signature, base)
        else
          Federails.logger.warn { "[Signature] Unknown RFC 9421 algorithm '#{algorithm}', trying rsa-pss-sha512" }
          key.verify_pss('SHA512', signature, base, salt_length: :auto, mgf1_hash: 'SHA512')
        end
      rescue OpenSSL::PKey::PKeyError => e
        Federails.logger.warn { "[Signature] RFC 9421 verify error: #{e.message}" }
        false
      end

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
