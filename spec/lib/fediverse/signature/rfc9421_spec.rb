require 'rails_helper'
require 'fediverse/signature/rfc9421'

RSpec.describe Fediverse::Signature::Rfc9421 do
  let(:actor) { FactoryBot.create(:user).fedipub_actor }

  before do
    actor.send :ensure_key_pair_exists!
  end

  context 'when signing POST requests' do
    let(:request) do
      Faraday.default_connection.build_request(:post) do |req|
        req.url '/inbox'
        req.body = 'test'
        req.headers['Host'] = 'example.com'
        req.headers['Date'] = Time.now.utc.httpdate
      end
    end
    let(:signed_request) { described_class.sign(sender: actor, request: request) }

    it 'adds Content-Digest header to request' do
      expect(signed_request.headers['Content-Digest']).to eq 'sha-256=:n4bQgYhMfWWaL+qgxVrQFaO/TxsrC4Is0V1sFbDwCgg=:'
    end

    it 'adds Signature header to request' do
      expect(signed_request.headers['Signature']).to be_present
    end

    it 'adds Signature-Input header to request' do
      expect(signed_request.headers['Signature-Input']).to be_present
    end

    it 'includes method' do
      expect(signed_request.headers['Signature-Input']).to include('"@method"')
    end

    it 'includes target URI' do
      expect(signed_request.headers['Signature-Input']).to include('"@target-uri"')
    end

    it 'includes digest' do
      expect(signed_request.headers['Signature-Input']).to include('"content-digest"')
    end

    it 'includes signature' do
      expect(signed_request.headers['Signature']).to match %r{^sig1=:[[[:alnum:]]-+/]*={0,3}:$}
    end

    it 'includes key ID in signature' do
      expect(signed_request.headers['Signature-Input']).to include "keyid=\"#{actor.federated_url}#main-key\""
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

    it 'throws signature error if signature is bad' do
      bad_request = signed_request
      bad_request.headers['Signature'] = 'sig1=::'
      expect { described_class.verify!(request: signed_request) }.to raise_error(Fediverse::Signature::BadSignature)
    end

    it 'throws signature error if input is wrong' do
      bad_request = signed_request
      bad_request.headers['Signature-Input'] = "sig1=(\"@method\");created=#{Time.now.utc.to_i}"
      expect { described_class.verify!(request: signed_request) }.to raise_error(Fediverse::Signature::BadSignature)
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
      expect(signed_request.headers['Content-Digest']).not_to be_present
    end

    it 'includes digest' do
      expect(signed_request.headers['Signature-Input']).not_to include('"content-digest"')
    end

    it 'is verifiable' do
      expect(described_class.verify!(request: signed_request)).to be true
    end
  end
end
