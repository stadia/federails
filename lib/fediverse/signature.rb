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

      BODY_INTEGRITY_COMPONENTS = %w[content-digest digest].freeze
      private_constant :BODY_INTEGRITY_COMPONENTS

      def verify_rfc9421_request!(request)
        candidates = parse_rfc9421_candidates(request.headers['Signature'], request.headers['Signature-Input'])
        raise SignatureVerificationError, 'No valid RFC 9421 signatures' if candidates.empty?

        last_error = nil
        candidates.each do |parsed|
          actor = try_verify_rfc9421_candidate(request, parsed)
          return actor if actor
        rescue SignatureVerificationError => e
          last_error = "label=#{parsed[:label]}: #{e.message}"
        end

        raise SignatureVerificationError, last_error || 'Signature verification failed'
      end

      # Verify one RFC 9421 candidate signature. Returns actor on success, nil on
      # non-fatal failure (so the caller can try the next candidate), raises on
      # fatal verification failure.
      def try_verify_rfc9421_candidate(request, parsed)
        digest_component = (parsed[:components] & BODY_INTEGRITY_COMPONENTS).first
        raise SignatureVerificationError, 'body integrity not covered (missing content-digest/digest)' unless digest_component

        verify_body_digest!(request, digest_component)

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

        raise SignatureVerificationError, 'signature verification failed'
      end

      # Verify the body digest referenced by the RFC 9421 component list.
      # Accepts either the legacy Digest header or the RFC 9421 Content-Digest header.
      def verify_body_digest!(request, component)
        body = request.body.read
        request.body.rewind if request.body.respond_to?(:rewind)

        case component
        when 'content-digest'
          header = request.headers['Content-Digest']
          raise SignatureVerificationError, 'Missing Content-Digest header' if header.blank?

          digests = header.scan(/([A-Za-z0-9-]+)=:([^:]+):/)
          raise SignatureVerificationError, 'Malformed Content-Digest header' if digests.empty?

          matched = digests.any? do |algo, b64|
            digest_name = case algo.downcase
                          when 'sha-256' then 'SHA256'
                          when 'sha-512' then 'SHA512'
                          end
            next false unless digest_name

            expected = Base64.strict_encode64(OpenSSL::Digest.new(digest_name).digest(body))
            ActiveSupport::SecurityUtils.secure_compare(b64, expected)
          end

          raise SignatureVerificationError, 'Content-Digest mismatch' unless matched
        when 'digest'
          header = request.headers['Digest']
          raise SignatureVerificationError, 'Missing Digest header' if header.blank?

          expected = "SHA-256=#{Base64.strict_encode64(OpenSSL::Digest.new('SHA256').digest(body))}"
          raise SignatureVerificationError, 'Digest mismatch' unless ActiveSupport::SecurityUtils.secure_compare(header, expected)
        end
      end

      # Parse RFC 9421 Signature + Signature-Input headers, returning one entry per label.
      # Signature:       sig1=:base64bytes:, sig2=:base64bytes:
      # Signature-Input: sig1=("@method" "@path");keyid="...";alg="rsa-pss-sha512", sig2=(...)...
      def parse_rfc9421_candidates(sig_header, sig_input_header)
        raise SignatureVerificationError, 'Missing Signature-Input header' if sig_input_header.blank?

        sigs = sig_header.scan(/(\w+)=:([A-Za-z0-9+\/=]*):\s*/).to_h
        raise SignatureVerificationError, 'No valid signatures in Signature header' if sigs.empty?

        inputs = split_signature_input(sig_input_header)

        sigs.filter_map do |label, raw_b64|
          input_params = inputs[label]
          next unless input_params

          components_match = input_params.match(/\A\((.*?)\)/)
          next unless components_match

          components = components_match[1].scan(/"([^"]+)"/).flatten
          key_id     = input_params.match(/;keyid="([^"]+)"/)&.captures&.first
          next if key_id.blank?

          algorithm = input_params.match(/;alg="([^"]+)"/)&.captures&.first

          {
            label:        label,
            key_id:       key_id,
            components:   components,
            signature:    Base64.decode64(raw_b64),
            algorithm:    algorithm,
            input_params: input_params,
          }
        end
      end

      # Split a Signature-Input header value into { label => params } pairs.
      # Entries are separated by "," at the top level (not inside the component list parens).
      def split_signature_input(header)
        header.split(/,(?=\s*\w+=\()/).each_with_object({}) do |entry, acc|
          label, params = entry.strip.split('=', 2)
          acc[label] = params if label && params
        end
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

      # Verify an RFC 9421 signature. Uses digest-output-length salt for PSS
      # variants, which matches the default used by most signers.
      def rfc9421_verify(key, signature, base, algorithm)
        case algorithm
        when 'rsa-pss-sha512'
          key.verify_pss('SHA512', signature, base, salt_length: 64, mgf1_hash: 'SHA512')
        when 'rsa-pss-sha256'
          key.verify_pss('SHA256', signature, base, salt_length: 32, mgf1_hash: 'SHA256')
        when 'rsa-v1_5-sha256', nil
          key.verify(OpenSSL::Digest.new('SHA256'), signature, base)
        else
          Federails.logger.warn { "[Signature] Unknown RFC 9421 algorithm '#{algorithm}', trying rsa-pss-sha512" }
          key.verify_pss('SHA512', signature, base, salt_length: 64, mgf1_hash: 'SHA512')
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
