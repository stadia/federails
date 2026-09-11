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
    it 'delegates to DraftCavage12' do
      allow(Fediverse::Signature::DraftCavage12).to receive(:verify)
      described_class.verify(sender: sender, request: request, require_signature: true)
      expect(Fediverse::Signature::DraftCavage12).to have_received(:verify).with(sender: sender, request: request, require_signature: true)
    end
  end
end
