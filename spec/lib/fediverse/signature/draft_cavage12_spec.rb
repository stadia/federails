require 'rails_helper'
require 'fediverse/signature/draft_cavage12'

RSpec.describe Fediverse::Signature::DraftCavage12 do
  let(:actor) { FactoryBot.create(:user).fedipub_actor }

  context 'when signing requests' do
    let(:request) do
      Faraday.default_connection.build_request(:post) do |req|
        req.url '/inbox'
        req.body = 'test'
        req.headers['Host'] = 'example.com'
        req.headers['Date'] = Time.now.utc.httpdate
      end
    end
    let(:signed_request) { described_class.sign(sender: actor, request: request) }
    let(:signature) { signed_request.headers['Signature'] }

    it 'adds Digest header to request' do
      expect(signed_request.headers['Digest']).to eq 'SHA-256=n4bQgYhMfWWaL+qgxVrQFaO/TxsrC4Is0V1sFbDwCgg='
    end

    context 'when generating signature payload' do
      let(:payload) { described_class.send(:signature_payload, request: request) }

      it 'starts with request target' do
        expect(payload).to match(%r{\A\(request-target\): post /inbox$})
      end

      it 'includes host' do
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
      expect(described_class.verify(sender: actor, request: signed_request)).to be true
    end

    it 'fails verification if signature is bad' do
      bad_request = signed_request
      bad_request.headers['Signature'] = 'sig1=::'
      expect(described_class.verify(sender: actor, request: bad_request)).to be false
    end
  end
end
