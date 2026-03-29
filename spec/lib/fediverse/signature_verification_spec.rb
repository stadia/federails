require 'rails_helper'
require 'fediverse/signature'

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
end
