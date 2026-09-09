require 'rails_helper'
require 'fediverse/signature/rfc9421'

RSpec.describe Fediverse::Signature::Rfc9421 do
  let(:actor) { FactoryBot.create(:user).fedipub_actor }

  context 'when signing requests' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    let(:request) do
      Faraday.default_connection.build_request(:post) do |req|
        req.url '/inbox'
        req.body = 'test'
        req.headers['Host'] = 'example.com'
        req.headers['Date'] = Time.now.utc.httpdate
      end
    end
    let(:signed_request) { described_class.sign(sender: actor, request: request) }
    let(:signature_input) { signed_request.headers['Signature-Input'] }
    let(:signature) { signed_request.headers['Signature'] }
    let(:signature_parts) { signature.split(',') }

    it 'adds Content-Digest header to request' do
      expect(signed_request.headers['Content-Digest']).to eq 'sha-256=:n4bQgYhMfWWaL+qgxVrQFaO/TxsrC4Is0V1sFbDwCgg=:'
    end
  end
end
