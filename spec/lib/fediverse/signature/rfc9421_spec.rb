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
      expect(described_class.verify!(request: signed_request)).to eq actor
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
      expect(described_class.verify!(request: signed_request)).to eq actor
    end
  end

  context 'when verifying incoming ActionDispatch::Requests' do
    let(:request) do
      req = ActionDispatch::TestRequest.create
      req.request_method = 'GET'
      req.headers['Signature'] = 'sig1=:e8UJ5wMiRaonlth5ERtE8GIiEH7Akcr493nQ07VPNo6y3qvjdKt0fo8VHO8xXDjmtYoatGYBGJVlMfIp06eVMEyNW2I4vN7XDAz7m5v1108vGzaDljrd0H8+SJ28g7bzn6h2xeL/8q+qUwahWA/JmC8aOC9iVnwbOKCc0WSrLgWQwTY6VLp42Qt7jjhYT5W7/wCvfK9A1VmHH1lJXsV873Z6hpxesd50PSmO+xaNeYvDLvVdZlhtw5PCtUYzKjHqwmaQ6DEuM8udRjYsoNqp2xZKcuCO1nKc0V3RjpqMZLuuyVbHDAbCzr0pg2d2VM/OC33JAU7meEjjaNz+d7LWPg==:'
      req.headers['Signature-Input'] = "sig1=(\"@method\" \"@target-uri\" \"content-digest\");created=#{Time.now.to_i};keyid=\"http://activitypub.rocks/actor#mainKey\""
      req.headers['Content-Digest'] = 'abc123'
      req
    end
    let(:sender) { FactoryBot.create :distant_actor, :with_public_key }

    before do
      allow(Fedipub::Actor).to receive(:find_or_create_by_federation_url).and_return(sender)
    end

    it 'fetches sender details' do
      allow(described_class).to receive(:linzer_public_key).with(sender).and_return(double(verify: true))
      described_class.verify!(request: request)
      expect(Fedipub::Actor).to have_received(:find_or_create_by_federation_url).with('http://activitypub.rocks/actor').once
    end

    # We don't do the actual verification here because the signature isn't valid, but this tests
    # everything else, e.g. all our reading from the request object, etc
    it 'gets as far as verifying' do
      allow(Linzer).to receive(:verify).and_return(true)
      described_class.verify!(request: request)
      expect(Linzer).to have_received(:verify).once
    end
  end

  context 'when checking what an incoming signature covers' do
    define_method(:incoming_request) do |components:, body: nil|
      req = ActionDispatch::TestRequest.create('RAW_POST_DATA' => body)
      req.request_method = body ? 'POST' : 'GET'
      req.headers['Signature'] = 'sig1=:c2ln:'
      req.headers['Signature-Input'] = "sig1=(#{components.map { |c| %("#{c}") }.join(' ')});created=#{Time.now.to_i};keyid=\"#{actor.key_id}\""
      req
    end

    it 'rejects signatures that do not cover the target URI' do
      expect { described_class.verify!(request: incoming_request(components: %w[@method])) }
        .to raise_error(Fediverse::Signature::BadSignature, /@target-uri/)
    end

    it 'rejects signatures on requests with a body that do not cover the content digest' do
      expect { described_class.verify!(request: incoming_request(components: %w[@method @target-uri], body: '{}')) }
        .to raise_error(Fediverse::Signature::BadSignature, /content-digest/)
    end
  end

  context 'when the sender key may have been rotated' do
    let(:sender) { FactoryBot.create :distant_actor, :with_public_key }
    let(:request) do
      req = ActionDispatch::TestRequest.create
      req.request_method = 'GET'
      req.headers['Signature'] = 'sig1=:c2ln:'
      req.headers['Signature-Input'] = "sig1=(\"@method\" \"@target-uri\");created=#{Time.now.to_i};keyid=\"#{sender.federated_url}#main-key\""
      req
    end

    before do
      allow(Fedipub::Actor).to receive(:find_or_create_by_federation_url).and_return(sender)
      allow(sender).to receive(:sync!).and_return(true)
      allow(described_class).to receive(:linzer_public_key).with(sender).and_return(:key)
    end

    it 'refreshes a stale sender and retries' do
      sender.update_column(:updated_at, 2.days.ago) # rubocop:disable Rails/SkipsModelValidations
      calls = 0
      allow(Linzer).to receive(:verify) do
        calls += 1
        raise Linzer::VerifyError, 'bad' if calls == 1

        true
      end
      expect(described_class.verify!(request: request)).to eq sender
      expect(sender).to have_received(:sync!).once
    end

    it 'does not refresh a recently updated sender' do
      allow(Linzer).to receive(:verify).and_raise(Linzer::VerifyError, 'bad')
      expect { described_class.verify!(request: request) }.to raise_error(Fediverse::Signature::BadSignature)
      expect(sender).not_to have_received(:sync!)
    end

    it 'converts sender lookup failures into bad signatures' do
      allow(Fedipub::Actor).to receive(:find_or_create_by_federation_url).and_raise(ActiveRecord::RecordNotFound)
      expect { described_class.verify!(request: request) }.to raise_error(Fediverse::Signature::BadSignature)
    end

    it 'converts an invalid public key into a bad signature' do
      allow(described_class).to receive(:linzer_public_key).and_call_original
      sender.public_key = 'not a key'
      expect { described_class.verify!(request: request) }.to raise_error(Fediverse::Signature::BadSignature, /Invalid public key/)
    end

    it 'converts an invalid public key fetched while refreshing into a bad signature' do
      sender.update_column(:updated_at, 2.days.ago) # rubocop:disable Rails/SkipsModelValidations
      allow(described_class).to receive(:linzer_public_key).and_call_original
      allow(Linzer).to receive(:verify).and_raise(Linzer::VerifyError, 'bad')
      allow(sender).to receive(:sync!) { sender.public_key = 'not a key' }
      expect { described_class.verify!(request: request) }.to raise_error(Fediverse::Signature::BadSignature, /Invalid public key/)
    end
  end

  context 'when verifying signatures with several labels' do
    let(:request) do
      Faraday.default_connection.build_request(:get) do |req|
        req.url 'https://example.com/actor'
      end
    end

    before { described_class.sign(sender: actor, request: request) }

    it 'accepts the request if one label is valid' do
      request.headers['Signature-Input'] = %(sig0=("@method" "@target-uri");created=#{Time.now.to_i};keyid="#{actor.key_id}", #{request.headers['Signature-Input']})
      request.headers['Signature'] = "sig0=:c2ln:, #{request.headers['Signature']}"
      expect(described_class.verify!(request: request)).to eq actor
    end

    it 'rejects signatures created too far in the future' do
      request.headers['Signature-Input'] = request.headers['Signature-Input'].sub(/created=\d+/, "created=#{2.hours.from_now.to_i}")
      expect { described_class.verify!(request: request) }.to raise_error(Fediverse::Signature::BadSignature, /future/)
    end

    it 'rejects signatures created too long ago' do
      request.headers['Signature-Input'] = request.headers['Signature-Input'].sub(/created=\d+/, "created=#{1.hour.ago.to_i}")
      expect { described_class.verify!(request: request) }.to raise_error(Fediverse::Signature::BadSignature, /ago/)
    end
  end
end
