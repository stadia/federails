require 'rails_helper'
require 'fediverse/signature/rfc9421'

RSpec.describe Fediverse::Signature::Rfc9421 do
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
  end
end
