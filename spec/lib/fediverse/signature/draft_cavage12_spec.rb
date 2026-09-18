require 'rails_helper'
require 'fediverse/signature/draft_cavage12'

RSpec.describe Fediverse::Signature::DraftCavage12 do
  let(:actor) { FactoryBot.create(:user).fedipub_actor }

  before do
    actor.send :ensure_key_pair_exists!
  end

  context 'when signing POST requests' do
    let(:request) do
      Faraday.default_connection.build_request(:post) do |req|
        req.url 'http://example.com/inbox'
        req.body = 'test'
      end
    end
    let(:signed_request) { described_class.sign(sender: actor, request: request) }
    let(:signature) { signed_request.headers['Signature'] }

    it 'adds Digest header to request' do
      expect(signed_request.headers['Digest']).to eq 'SHA-256=n4bQgYhMfWWaL+qgxVrQFaO/TxsrC4Is0V1sFbDwCgg='
    end

    it 'adds a Date header' do
      expect(signed_request.headers['Date']).to be_present
    end

    it 'adds a Host header' do
      expect(signed_request.headers['Host']).to eq 'example.com'
    end

    context 'when generating signature payload' do
      let(:payload) { described_class.send(:signature_payload, request: request) }

      it 'starts with request target' do
        expect(payload).to match(%r{\A\(request-target\): post /inbox$})
      end

      it 'includes host' do
        request.headers['Host'] = 'example.com'
        expect(payload).to match(/^host: example.com$/)
      end

      it 'includes date' do
        expect(payload).to match(/^date: #{request.headers['Date']}$/)
      end

      it 'ends with digest' do
        request.headers['Digest'] = 'fakedigest'
        expect(payload).to match(/^digest: fakedigest\Z/)
      end
    end

    it 'includes key in signature header' do
      expect(signature.split(',')[0]).to eq "keyId=\"#{actor.federated_url}#main-key\""
    end

    it 'includes header list in signature header' do
      expect(signature.split(',')[1]).to eq 'headers="(request-target) host date digest"'
    end

    it 'includes signature part in signature header' do
      expect(signature.split(',')[2]).to match %r{^signature="[[[:alnum:]]-+/]*={0,3}"$}
    end

    it 'is verifiable' do
      expect(described_class.verify!(request: signed_request)).to be true
    end

    it 'returns false if request is not signed' do
      expect(described_class.verify!(request: request)).to be false
    end

    it 'throws signature error if sender could not be found' do
      allow(Fedipub::Actor).to receive(:find_or_create_by_federation_url).and_return(nil)
      expect { described_class.verify!(request: signed_request) }.to raise_error(Fediverse::Signature::BadSignature)
    end

    it 'throws signature error if sender lookup raises RecordNotFound' do
      allow(Fedipub::Actor).to receive(:find_or_create_by_federation_url)
        .and_raise(ActiveRecord::RecordNotFound)
      expect { described_class.verify!(request: signed_request) }.to raise_error(Fediverse::Signature::BadSignature)
    end

    it 'fails verification if signature is bad' do
      bad_request = signed_request
      bad_request.headers['Signature'] = 'sig1=::'
      expect { described_class.verify!(request: bad_request) }.to raise_error(Fediverse::Signature::BadSignature)
    end
  end

  context 'when signing GET requests' do
    let(:request) do
      Faraday.default_connection.build_request(:get) do |req|
        req.url 'http://example.com/outbox'
      end
    end
    let(:signed_request) { described_class.sign(sender: actor, request: request) }
    let(:signature) { signed_request.headers['Signature'] }

    it 'does not add Digest header' do
      expect(signed_request.headers['Digest']).not_to be_present
    end

    context 'when generating signature payload' do
      let(:payload) { described_class.send(:signature_payload, request: request) }

      it 'starts with request target' do
        expect(payload).to match(%r{\A\(request-target\): get /outbox$})
      end

      it 'includes host' do
        request.headers['Host'] = 'example.com'
        expect(payload).to match(/^host: example.com$/)
      end

      it 'includes date' do
        expect(payload).to match(/^date: #{request.headers['Date']}$/)
      end

      it 'does not include digest' do
        expect(payload).not_to include('digest:')
      end
    end

    it 'is verifiable' do
      expect(described_class.verify!(request: signed_request)).to be true
    end
  end

  context 'when verifying incoming ActionDispatch::Requests' do
    let(:request) do
      req = ActionDispatch::TestRequest.create
      req.request_method = 'GET'
      req.headers['Signature'] = 'keyId="http://activitypub.rocks/actor#mainKey",algorithm="rsa-sha256",headers="(request-target) host date digest",signature="SjWJWbWN7i0wzBvtPl8rbASWz5xQW6mcJmn+ibttBqtifLN7Sazz6m79cNfwwb8DMJ5cou1s7uEGKKCs+FLEEaDV5lp7q25WqS+lavg7T8hc0GppauB6hbgEKTwblDHYGEtbGmtdHgVCk9SuS13F0hZ8FD0k/5OxEPXe5WozsbM="'
      req.headers['Digest'] = 'abc123'
      req.headers['Date'] = 'date'
      req
    end
    let(:sender) { FactoryBot.create :distant_actor }

    before do
      allow(Fedipub::Actor).to receive(:find_or_create_by_federation_url).and_return(sender)
      allow(described_class).to receive(:do_verification).and_return(true)
      described_class.verify!(request: request)
    end

    it 'fetches sender details' do
      expect(Fedipub::Actor).to have_received(:find_or_create_by_federation_url).with('http://activitypub.rocks/actor').once
    end

    # We don't do the actual verification here because the signature isn't valid, but this tests
    # everything else, e.g. all our reading from the request object, etc
    it 'gets as far as verifying' do
      expect(described_class).to have_received(:do_verification).with(
        'SjWJWbWN7i0wzBvtPl8rbASWz5xQW6mcJmn+ibttBqtifLN7Sazz6m79cNfwwb8DMJ5cou1s7uEGKKCs+FLEEaDV5lp7q25WqS+lavg7T8hc0GppauB6hbgEKTwblDHYGEtbGmtdHgVCk9SuS13F0hZ8FD0k/5OxEPXe5WozsbM=',
        sender,
        "(request-target): get /\nhost: test.host\ndate: date\ndigest: abc123"
      ).once
    end
  end
end
