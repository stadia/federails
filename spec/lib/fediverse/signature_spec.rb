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

    it 'short-circuits draft-cavage-12 if Rfc9421 throws a bad signature error' do # rubocop:todo RSpec/ExampleLength
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
end
