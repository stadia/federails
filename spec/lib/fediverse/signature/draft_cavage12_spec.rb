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
      expect(described_class.verify!(request: signed_request)).to eq actor
    end

    it 'returns false if request is not signed' do
      expect(described_class.verify!(request: request)).to be false
    end

    it 'throws signature error if sender could not be found' do
      allow(Fedipub::Actor).to receive(:find_or_create_by_federation_url).and_return(nil)
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
      expect(described_class.verify!(request: signed_request)).to eq actor
    end
  end

  context 'when verifying incoming ActionDispatch::Requests' do
    let(:request) do
      req = ActionDispatch::TestRequest.create
      req.request_method = 'GET'
      req.headers['Signature'] = 'keyId="http://activitypub.rocks/actor#mainKey",algorithm="rsa-sha256",headers="(request-target) host date digest",signature="SjWJWbWN7i0wzBvtPl8rbASWz5xQW6mcJmn+ibttBqtifLN7Sazz6m79cNfwwb8DMJ5cou1s7uEGKKCs+FLEEaDV5lp7q25WqS+lavg7T8hc0GppauB6hbgEKTwblDHYGEtbGmtdHgVCk9SuS13F0hZ8FD0k/5OxEPXe5WozsbM="'
      req.headers['Digest'] = 'abc123'
      req.headers['Date'] = date
      req
    end
    let(:date) { Time.now.utc.httpdate }
    let(:sender) { FactoryBot.create :distant_actor, :with_public_key }

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
        "(request-target): get /\nhost: test.host\ndate: #{date}\ndigest: abc123"
      ).once
    end
  end

  context 'when checking what an incoming signature covers' do
    let(:sender) { FactoryBot.create :distant_actor, :with_public_key }

    define_method(:incoming_request) do |headers:, date: Time.now.utc.httpdate, body: nil, path: '/'|
      req = ActionDispatch::TestRequest.create('RAW_POST_DATA' => body, 'PATH_INFO' => path)
      req.request_method = body ? 'POST' : 'GET'
      req.headers['Signature'] = %(keyId="#{sender.key_id}",headers="#{headers}",signature="c2ln")
      req.headers['Date'] = date
      req
    end

    before do
      allow(Fedipub::Actor).to receive(:find_or_create_by_federation_url).and_return(sender)
    end

    it 'rejects signatures that do not cover the request target' do
      expect { described_class.verify!(request: incoming_request(headers: 'host date')) }
        .to raise_error(Fediverse::Signature::BadSignature, /\(request-target\)/)
    end

    it 'rejects signatures on requests with a body that do not cover the digest' do
      expect { described_class.verify!(request: incoming_request(headers: '(request-target) host date', body: '{}')) }
        .to raise_error(Fediverse::Signature::BadSignature, /digest/)
    end

    it 'rejects signatures with an expired date' do
      expect { described_class.verify!(request: incoming_request(headers: '(request-target) host date', date: 2.days.ago.httpdate)) }
        .to raise_error(Fediverse::Signature::BadSignature, /date/)
    end

    it 'includes the query string in the request target' do
      allow(described_class).to receive(:do_verification).and_return(true)
      request = incoming_request(headers: '(request-target) host date')
      request.set_header('QUERY_STRING', 'page=2')
      described_class.verify!(request: request)
      expect(described_class).to have_received(:do_verification).with(anything, sender, a_string_starting_with("(request-target): get /?page=2\n"))
    end

    it 'refreshes a stale sender and retries when verification fails' do
      sender.update_column(:updated_at, 2.days.ago) # rubocop:disable Rails/SkipsModelValidations
      allow(described_class).to receive(:do_verification).and_return(false, true)
      allow(sender).to receive(:sync!).and_return(true)
      expect(described_class.verify!(request: incoming_request(headers: '(request-target) host date'))).to eq sender
      expect(sender).to have_received(:sync!).once
    end

    it 'does not refresh a recently updated sender' do
      allow(described_class).to receive(:do_verification).and_return(false)
      allow(sender).to receive(:sync!)
      expect { described_class.verify!(request: incoming_request(headers: '(request-target) host date')) }
        .to raise_error(Fediverse::Signature::BadSignature)
      expect(sender).not_to have_received(:sync!)
    end

    it 'converts sender lookup failures into bad signatures' do
      allow(Fedipub::Actor).to receive(:find_or_create_by_federation_url).and_raise(ActiveRecord::RecordNotFound)
      expect { described_class.verify!(request: incoming_request(headers: '(request-target) host date')) }
        .to raise_error(Fediverse::Signature::BadSignature)
    end
  end

  context 'when signing a request with query parameters' do
    let(:sender) { FactoryBot.create(:user).fedipub_actor }

    it 'includes the query string in the request target' do
      request = Faraday.default_connection.build_request(:get) do |req|
        req.url 'https://example.com/.well-known/webfinger'
        req.params = { 'resource' => 'acct:alice@example.com' }
      end
      described_class.sign(sender: sender, request: request)
      expect(described_class.send(:signature_payload, request: request))
        .to start_with("(request-target): get /.well-known/webfinger?resource=acct%3Aalice%40example.com\n")
    end
  end
end
