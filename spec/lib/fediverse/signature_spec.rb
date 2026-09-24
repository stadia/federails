require 'rails_helper'
require 'fediverse/signature'

RSpec.describe Fediverse::Signature do
  let(:sender) { 'alice' }
  let(:request) { 'request' }

  context 'when signing' do
    it 'delegates to Rfc9412 by default' do
      allow(Fediverse::Signature::Rfc9421).to receive(:sign)
      described_class.sign(sender: sender, request: request)
      expect(Fediverse::Signature::Rfc9421).to have_received(:sign).with(sender: sender, request: request)
    end

    it 'delegates to DraftCavage12 if told to use legacy signatures' do
      allow(Fediverse::Signature::DraftCavage12).to receive(:sign)
      described_class.sign(sender: sender, request: request, legacy_signature: true)
      expect(Fediverse::Signature::DraftCavage12).to have_received(:sign).with(sender: sender, request: request)
    end
  end

  context 'when verifying' do
    it 'delegates to Rfc9421 first' do
      allow(Fediverse::Signature::Rfc9421).to receive(:verify!).and_return true
      described_class.verify!(request: request, require_signature: true)
      expect(Fediverse::Signature::Rfc9421).to have_received(:verify!).with(request: request).once
    end

    it 'short-circuits draft-cavage-12 if Rfc9421 throws a bad signature error' do
      allow(Fediverse::Signature::Rfc9421).to receive(:verify!).and_raise(Fediverse::Signature::BadSignature)
      allow(Fediverse::Signature::DraftCavage12).to receive(:verify!).and_return true
      begin
        described_class.verify!(request: request, require_signature: true)
      rescue Fediverse::Signature::BadSignature
        nil
      end
      expect(Fediverse::Signature::DraftCavage12).not_to have_received(:verify!)
    end

    it 'delegates to DraftCavage12 if Rfc9421 signature not present' do
      allow(Fediverse::Signature::Rfc9421).to receive(:verify!).and_return false
      allow(Fediverse::Signature::DraftCavage12).to receive(:verify!).and_return true
      described_class.verify!(request: request, require_signature: true)
      expect(Fediverse::Signature::DraftCavage12).to have_received(:verify!).with(request: request).once
    end

    it 'throws error if neither signature is present and if signatures are required' do
      allow(Fediverse::Signature::Rfc9421).to receive(:verify!).and_return false
      allow(Fediverse::Signature::DraftCavage12).to receive(:verify!).and_return false
      expect { described_class.verify!(request: request, require_signature: true) }.to raise_error(Fediverse::Signature::BadSignature)
    end

    it 'passes if RFC9421 passes' do
      allow(Fediverse::Signature::Rfc9421).to receive(:verify!).and_return true
      expect(described_class.verify!(request: request, require_signature: true)).to be true
    end

    it 'passes if Rfc9421 signature not present but DraftCavage12 passes' do
      allow(Fediverse::Signature::Rfc9421).to receive(:verify!).and_return false
      allow(Fediverse::Signature::DraftCavage12).to receive(:verify!).and_return true
      expect(described_class.verify!(request: request, require_signature: true)).to be true
    end

    it 'passes if signature not present for either but signature is not required' do
      allow(Fediverse::Signature::Rfc9421).to receive(:verify!).and_return false
      allow(Fediverse::Signature::DraftCavage12).to receive(:verify!).and_return false
      expect(described_class.verify!(request: request, require_signature: false)).to be true
    end
  end

  describe '.verify_sender!' do
    let(:actor) { FactoryBot.create(:user).fedipub_actor }

    it 'returns the actor whose key verified the request' do
      allow(Fediverse::Signature::Rfc9421).to receive(:verify!).and_return(actor)
      expect(described_class.verify_sender!(request: request)).to eq actor
    end

    it 'returns nil for unsigned requests' do
      allow(Fediverse::Signature::Rfc9421).to receive(:verify!).and_return false
      allow(Fediverse::Signature::DraftCavage12).to receive(:verify!).and_return false
      expect(described_class.verify_sender!(request: request)).to be_nil
    end
  end

  describe '.find_sender' do
    let(:remote) { FactoryBot.create :distant_actor, :with_public_key }

    it 'strips the key fragment' do
      allow(Fedipub::Actor).to receive(:find_or_create_by_federation_url).with(remote.federated_url).and_return(remote)
      expect(described_class.find_sender("#{remote.federated_url}#main-key")).to eq remote
    end

    it 'rejects a missing key id' do
      expect { described_class.find_sender(nil) }.to raise_error(Fediverse::Signature::BadSignature)
    end

    it 'rejects actors without a public key' do
      allow(Fedipub::Actor).to receive(:find_or_create_by_federation_url).and_return(FactoryBot.create(:distant_actor))
      expect { described_class.find_sender('https://example.com/actor#main-key') }.to raise_error(Fediverse::Signature::BadSignature, /no public key/)
    end

    [Faraday::TimeoutError, Faraday::SSLError, ActiveRecord::RecordNotFound, JSON::ParserError, URI::InvalidURIError].each do |error|
      it "converts #{error} into a bad signature" do
        allow(Fedipub::Actor).to receive(:find_or_create_by_federation_url).and_raise(error)
        expect { described_class.find_sender('https://example.com/actor#main-key') }.to raise_error(Fediverse::Signature::BadSignature, /#{error}/)
      end
    end
  end

  describe '.refresh_stale_sender!' do
    let(:remote) { FactoryBot.create :distant_actor, :with_public_key, updated_at: 2.days.ago }

    it 'ignores local actors' do
      expect(described_class.refresh_stale_sender!(FactoryBot.create(:user).fedipub_actor)).to be false
    end

    it 'ignores recently updated actors' do
      remote.touch # rubocop:disable Rails/SkipsModelValidations
      allow(remote).to receive(:sync!)
      expect(described_class.refresh_stale_sender!(remote)).to be false
      expect(remote).not_to have_received(:sync!)
    end

    it 'refreshes stale actors and bumps their timestamp even when nothing changed' do
      allow(remote).to receive(:sync!).and_return(true)
      expect(described_class.refresh_stale_sender!(remote)).to be true
      expect(remote.reload.updated_at).to be > 1.minute.ago
    end

    it 'converts refresh failures into bad signatures and still bumps the timestamp' do
      allow(remote).to receive(:sync!).and_raise(Faraday::TimeoutError)
      expect { described_class.refresh_stale_sender!(remote) }.to raise_error(Fediverse::Signature::BadSignature, /Unable to refresh/)
      expect(remote.reload.updated_at).to be > 1.minute.ago
    end
  end

  describe '.body?' do
    it 'is false for an empty body' do
      expect(described_class.body?(Struct.new(:body).new(StringIO.new('')))).to be false
    end

    it 'is true for a non-empty body, and rewinds it' do
      body = StringIO.new('{}')
      expect(described_class.body?(Struct.new(:body).new(body))).to be true
      expect(body.read).to eq '{}'
    end
  end
end
