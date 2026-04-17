require 'rails_helper'
require 'fediverse/signature'

# Minimal stand-in exposing the request surface Signature.verify_request! uses.
# Defined at file scope to avoid Lint/ConstantDefinitionInBlock and leaky-constant warnings.
Rfc9421MockRequest = Struct.new(:body, :headers) do
  def method = 'POST'
  def url = 'https://example.com/inbox'
  def host = 'example.com'
  def port = 443
  def scheme = 'https'
  def standard_port? = true
end

RSpec.describe Fediverse::Signature do
  let(:actor) { FactoryBot.create(:user).federails_actor }

  describe '.parse_signature_header' do
    it 'parses a valid signature header' do
      header = 'keyId="https://example.com/actor#main-key",headers="(request-target) host date digest",signature="abc123="'
      result = described_class.parse_signature_header(header)

      expect(result).to eq(
        key_id:    'https://example.com/actor#main-key',
        headers:   '(request-target) host date digest',
        signature: 'abc123=',
        algorithm: nil
      )
    end

    it 'parses algorithm when present' do
      header = 'keyId="https://example.com/actor#main-key",algorithm="rsa-sha256",headers="(request-target) host date",signature="abc="'
      result = described_class.parse_signature_header(header)

      expect(result[:algorithm]).to eq('rsa-sha256')
    end

    it 'raises on nil header' do
      expect { described_class.parse_signature_header(nil) }
        .to raise_error(Fediverse::Signature::SignatureVerificationError, /Missing Signature header/)
    end

    it 'raises on empty header' do
      expect { described_class.parse_signature_header('') }
        .to raise_error(Fediverse::Signature::SignatureVerificationError, /Missing Signature header/)
    end

    it 'raises when keyId is missing' do
      header = 'headers="(request-target)",signature="abc="'
      expect { described_class.parse_signature_header(header) }
        .to raise_error(Fediverse::Signature::SignatureVerificationError, /missing keyId/)
    end

    it 'raises when signature is missing' do
      header = 'keyId="https://example.com/actor#main-key",headers="(request-target)"'
      expect { described_class.parse_signature_header(header) }
        .to raise_error(Fediverse::Signature::SignatureVerificationError, /missing signature/)
    end

    it 'raises when headers is missing' do
      header = 'keyId="https://example.com/actor#main-key",signature="abc="'
      expect { described_class.parse_signature_header(header) }
        .to raise_error(Fediverse::Signature::SignatureVerificationError, /missing headers/)
    end
  end

  describe '.verify_digest!' do
    let(:body) { '{"type":"Create"}' }
    let(:correct_digest) { "SHA-256=#{Base64.strict_encode64(OpenSSL::Digest.new('SHA256').digest(body))}" }

    def build_request(body_str, digest_header)
      req = Faraday.default_connection.build_request(:post) do |r|
        r.url '/inbox'
        r.body = body_str
        r.headers['Digest'] = digest_header if digest_header
      end
      # Wrap body in StringIO to support read/rewind
      req.define_singleton_method(:body) { @body ||= StringIO.new(body_str) }
      req
    end

    it 'passes with correct digest' do
      request = build_request(body, correct_digest)
      expect { described_class.verify_digest!(request) }.not_to raise_error
    end

    it 'raises when Digest header is missing' do
      request = build_request(body, nil)
      expect { described_class.verify_digest!(request) }
        .to raise_error(Fediverse::Signature::SignatureVerificationError, /Missing Digest header/)
    end

    it 'raises on digest mismatch' do
      request = build_request(body, 'SHA-256=wrongdigest')
      expect { described_class.verify_digest!(request) }
        .to raise_error(Fediverse::Signature::SignatureVerificationError, /Digest mismatch/)
    end

    it 'rewinds the body after reading' do
      request = build_request(body, correct_digest)
      described_class.verify_digest!(request)
      expect(request.body.read).to eq(body)
    end
  end

  describe '.verify_request!' do
    let(:body) { '{"type":"Create"}' }
    let(:digest) { "SHA-256=#{Base64.strict_encode64(OpenSSL::Digest.new('SHA256').digest(body))}" }

    def request_digest(body_str)
      "SHA-256=#{Base64.strict_encode64(OpenSSL::Digest.new('SHA256').digest(body_str))}"
    end

    def build_faraday_request(body_str)
      Faraday.default_connection.build_request(:post) do |r|
        r.url '/inbox'
        r.body = body_str
        r.headers['Host'] = 'example.com'
        r.headers['Date'] = Time.now.utc.httpdate
        r.headers['Digest'] = request_digest(body_str)
      end
    end

    def build_signed_request(signing_actor, body_str)
      req = build_faraday_request(body_str)
      req.headers['Signature'] = described_class.sign(sender: signing_actor, request: req)

      # Wrap body as StringIO for read/rewind support
      req.define_singleton_method(:body) { @body ||= StringIO.new(body_str) }
      req
    end

    it 'returns the actor on valid signature' do
      request = build_signed_request(actor, body)
      actor_uri = actor.federated_url

      allow(Federails::Actor).to receive(:find_or_create_by_federation_url)
        .with(actor_uri).and_return(actor)

      result = described_class.verify_request!(request)
      expect(result).to eq(actor)
    end

    it 'retries after sync! on initial verification failure when actor is stale' do
      request = build_signed_request(actor, body)
      actor_uri = actor.federated_url

      # Simulate key rotation: first call returns actor with wrong key, after sync! key is correct
      wrong_key = OpenSSL::PKey::RSA.new(2048)
      real_public_key = actor.class.find(actor.id).public_key

      allow(Federails::Actor).to receive(:find_or_create_by_federation_url)
        .with(actor_uri).and_return(actor)
      allow(actor).to receive(:public_key).and_return(wrong_key.public_key.to_pem, real_public_key)
      allow(actor).to receive(:updated_at).and_return(2.days.ago)
      allow(actor).to receive(:sync!)

      result = described_class.verify_request!(request)
      expect(result).to eq(actor)
      expect(actor).to have_received(:sync!)
    end

    it 'does not retry sync! when actor is fresh' do
      request = build_signed_request(actor, body)
      actor_uri = actor.federated_url

      wrong_key = OpenSSL::PKey::RSA.new(2048)

      allow(Federails::Actor).to receive(:find_or_create_by_federation_url)
        .with(actor_uri).and_return(actor)
      allow(actor).to receive_messages(public_key: wrong_key.public_key.to_pem, updated_at: 1.minute.ago)
      allow(actor).to receive(:sync!)

      expect { described_class.verify_request!(request) }
        .to raise_error(Fediverse::Signature::SignatureVerificationError, /Signature verification failed/)
      expect(actor).not_to have_received(:sync!)
    end

    it 'raises SignatureVerificationError when signature is invalid even after retry' do
      request = build_signed_request(actor, body)
      actor_uri = actor.federated_url

      wrong_key = OpenSSL::PKey::RSA.new(2048)

      allow(Federails::Actor).to receive(:find_or_create_by_federation_url)
        .with(actor_uri).and_return(actor)
      allow(actor).to receive_messages(public_key: wrong_key.public_key.to_pem, updated_at: 2.days.ago)
      allow(actor).to receive(:sync!)

      expect { described_class.verify_request!(request) }
        .to raise_error(Fediverse::Signature::SignatureVerificationError, /Signature verification failed/)
      expect(actor).to have_received(:sync!)
    end

    it 'strips the key fragment from keyId to get actor URI' do
      request = build_signed_request(actor, body)

      allow(Federails::Actor).to receive(:find_or_create_by_federation_url)
        .with(actor.federated_url).and_return(actor)

      described_class.verify_request!(request)

      expect(Federails::Actor).to have_received(:find_or_create_by_federation_url)
        .with(actor.federated_url)
    end

    it 'wraps actor lookup errors as SignatureVerificationError' do
      request = build_signed_request(actor, body)

      allow(Federails::Actor).to receive(:find_or_create_by_federation_url)
        .with(actor.federated_url).and_raise(ActiveRecord::RecordNotFound)

      expect { described_class.verify_request!(request) }
        .to raise_error(Fediverse::Signature::SignatureVerificationError, /Unable to load signed actor/)
    end

    it 'wraps stale actor refresh errors as SignatureVerificationError' do
      request = build_signed_request(actor, body)
      actor_uri = actor.federated_url
      wrong_key = OpenSSL::PKey::RSA.new(2048)

      allow(Federails::Actor).to receive(:find_or_create_by_federation_url)
        .with(actor_uri).and_return(actor)
      allow(actor).to receive_messages(public_key: wrong_key.public_key.to_pem, updated_at: 2.days.ago)
      allow(actor).to receive(:sync!).and_raise(Faraday::ConnectionFailed.new('boom'))

      expect { described_class.verify_request!(request) }
        .to raise_error(Fediverse::Signature::SignatureVerificationError, /Unable to refresh signed actor/)
    end
  end

  describe '.verify_request! with RFC 9421' do
    let(:body) { '{"type":"Create"}' }
    let(:content_digest) { "sha-256=:#{Base64.strict_encode64(OpenSSL::Digest.new('SHA256').digest(body))}:" }

    def build_rfc9421_request(body_str, signature_header, signature_input_header, content_digest_header: nil)
      headers = {
        'Signature'       => signature_header,
        'Signature-Input' => signature_input_header,
        'Content-Digest'  => content_digest_header,
      }
      Rfc9421MockRequest.new(StringIO.new(body_str), headers)
    end

    def rfc9421_raw_signature(private_key, base, algorithm)
      case algorithm
      when 'rsa-pss-sha512' then private_key.sign_pss('SHA512', base, salt_length: 64, mgf1_hash: 'SHA512')
      else private_key.sign(OpenSSL::Digest.new('SHA256'), base)
      end
    end

    def sign_rfc9421(signing_actor, components, body_str:, content_digest_header:, algorithm: 'rsa-v1_5-sha256', label: 'sig1')
      params = %(("#{components.join('" "')}");keyid="#{signing_actor.key_id}";alg="#{algorithm}";created=#{Time.now.to_i})
      request_like = build_rfc9421_request(body_str, '', '', content_digest_header: content_digest_header)
      base = described_class.send(:rfc9421_signature_base, request_like, components, params)
      private_key = OpenSSL::PKey::RSA.new(signing_actor.private_key, Rails.application.credentials.secret_key_base)
      raw_sig = rfc9421_raw_signature(private_key, base, algorithm)

      { signature: "#{label}=:#{Base64.strict_encode64(raw_sig)}:", signature_input: "#{label}=#{params}" }
    end

    it 'verifies a valid RFC 9421 signature (rsa-v1_5-sha256)' do
      components = %w[@method @path @authority content-digest]
      signed = sign_rfc9421(actor, components, body_str: body, content_digest_header: content_digest)
      request = build_rfc9421_request(body, signed[:signature], signed[:signature_input], content_digest_header: content_digest)

      allow(Federails::Actor).to receive(:find_or_create_by_federation_url)
        .with(actor.federated_url).and_return(actor)

      expect(described_class.verify_request!(request)).to eq(actor)
    end

    it 'verifies a valid RFC 9421 signature (rsa-pss-sha512)' do
      components = %w[@method @path content-digest]
      signed = sign_rfc9421(actor, components, algorithm: 'rsa-pss-sha512',
                                               body_str: body, content_digest_header: content_digest)
      request = build_rfc9421_request(body, signed[:signature], signed[:signature_input], content_digest_header: content_digest)

      allow(Federails::Actor).to receive(:find_or_create_by_federation_url)
        .with(actor.federated_url).and_return(actor)

      expect(described_class.verify_request!(request)).to eq(actor)
    end

    it 'rejects a signature that does not cover body integrity' do
      components = %w[@method @path]
      signed = sign_rfc9421(actor, components, body_str: body, content_digest_header: content_digest)
      request = build_rfc9421_request(body, signed[:signature], signed[:signature_input], content_digest_header: content_digest)

      expect { described_class.verify_request!(request) }
        .to raise_error(Fediverse::Signature::SignatureVerificationError, /body integrity not covered/)
    end

    it 'rejects a signature when the body does not match content-digest' do
      components = %w[@method @path content-digest]
      stale_digest = "sha-256=:#{Base64.strict_encode64(OpenSSL::Digest.new('SHA256').digest('other'))}:"
      signed = sign_rfc9421(actor, components, body_str: body, content_digest_header: stale_digest)
      request = build_rfc9421_request(body, signed[:signature], signed[:signature_input], content_digest_header: stale_digest)

      expect { described_class.verify_request!(request) }
        .to raise_error(Fediverse::Signature::SignatureVerificationError, /Content-Digest mismatch/)
    end

    it 'tries all candidate labels and accepts the second if the first is unverifiable' do
      components = %w[@method @path content-digest]

      # Label 1: unsupported algorithm over garbage (will fail)
      bad_params    = %(("@method");keyid="#{actor.key_id}";alg="unsupported-alg";created=1)
      bad_signature = 'sig1=:aW52YWxpZA==:'
      bad_input     = "sig1=#{bad_params}"

      # Label 2: valid signature
      good = sign_rfc9421(actor, components, label: 'sig2',
                                             body_str: body, content_digest_header: content_digest)

      signature_header       = "#{bad_signature}, #{good[:signature]}"
      signature_input_header = "#{bad_input}, #{good[:signature_input]}"

      request = build_rfc9421_request(body, signature_header, signature_input_header, content_digest_header: content_digest)

      allow(Federails::Actor).to receive(:find_or_create_by_federation_url)
        .with(actor.federated_url).and_return(actor)

      expect(described_class.verify_request!(request)).to eq(actor)
    end

    it 'raises when Signature-Input is missing' do
      request = build_rfc9421_request(body, 'sig1=:abc=:', nil, content_digest_header: content_digest)
      expect { described_class.verify_request!(request) }
        .to raise_error(Fediverse::Signature::SignatureVerificationError, /Missing Signature-Input/)
    end
  end
end
