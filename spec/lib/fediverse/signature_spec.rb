require 'rails_helper'
require 'fediverse/signature'

RSpec.describe Fediverse::Signature do
  let(:actor) { FactoryBot.create(:user).federails_actor }

  context 'when signing requests' do
    let(:request) do
      Faraday.default_connection.build_request(:post) do |req|
        req.url '/inbox'
        req.body = 'test'
        req.headers['Host'] = 'example.com'
        req.headers['Date'] = Time.now.utc.httpdate
        req.headers['Digest'] = 'fakedigest'
      end
    end
    let(:signature) { described_class.sign(sender: actor, request: request) }
    let(:signature_parts) { signature.split(',') }

    context 'when generating signature payload' do
      let(:payload) { described_class.send(:signature_payload, request: request, headers: '(request-target) host date digest') }

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
        expect(payload).to match(/^digest: fakedigest\Z/)
      end
    end

    it 'includes key in signature header' do
      expect(signature_parts[0]).to eq "keyId=\"#{actor.federated_url}#main-key\""
    end

    it 'includes header list in signature header' do
      expect(signature_parts[1]).to eq 'headers="(request-target) host date digest"'
    end

    it 'includes signature part in signature header' do
      expect(signature_parts[2]).to match %r{^signature="[[[:alnum:]]-+/]*={0,3}"$}
    end
  end

  describe '.verify' do
    let(:request) do
      Faraday.default_connection.build_request(:post) do |req|
        req.url '/inbox'
        req.body = 'test'
        req.headers['Host'] = 'example.com'
        req.headers['Date'] = Time.now.utc.httpdate
        req.headers['Digest'] = 'fakedigest'
      end
    end

    it 'verifies a valid signature' do
      request.headers['Signature'] = described_class.sign(sender: actor, request: request)

      expect(described_class.verify(sender: actor, request: request)).to be(true)
    end

    it 'returns false for a tampered request' do
      request.headers['Signature'] = described_class.sign(sender: actor, request: request)
      request.headers['Date'] = 1.day.from_now.utc.httpdate

      expect(described_class.verify(sender: actor, request: request)).to be(false)
    end

    it 'raises when signature header is missing' do
      expect do
        described_class.verify(sender: actor, request: request)
      end.to raise_error('Unsigned headers')
    end
  end

  describe '.signed_get' do
    let(:url) { 'https://example.com/actors/alice' }

    it 'returns parsed json on success' do
      outgoing_request = Struct.new(:headers).new({})
      response = instance_double(Faraday::Response, status: 200, body: '{"id":"https://example.com/actors/alice"}')

      allow(Faraday).to receive(:get).with(url).and_yield(outgoing_request).and_return(response)

      result = described_class.signed_get(url, actor: actor)

      aggregate_failures do
        expect(result).to eq('id' => url)
        expect(outgoing_request.headers['Accept']).to eq('application/activity+json')
        expect(outgoing_request.headers['Host']).to eq('example.com')
        expect(outgoing_request.headers['Signature']).to be_present
      end
    end

    it 'raises on non-200 responses' do
      outgoing_request = Struct.new(:headers).new({})
      response = instance_double(Faraday::Response, status: 404, body: 'not found')

      allow(Faraday).to receive(:get).with(url).and_yield(outgoing_request).and_return(response)

      expect do
        described_class.signed_get(url, actor: actor)
      end.to raise_error(Federails::Utils::JsonRequest::UnhandledResponseStatus, /404/)
    end
  end
end
