require 'rails_helper'
require 'fediverse/signature'

RSpec.describe Fediverse::Signature do
  let(:actor) { FactoryBot.create(:user).actor }

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
end
