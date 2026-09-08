require 'rails_helper'
require 'fediverse/signature'

RSpec.describe Fediverse::Signature do
  let(:sender) { 'alice' }
  let(:request) { 'request' }

  context 'when signing' do
    it 'delegates to DraftCavage12' do
      allow(Fediverse::Signature::DraftCavage12).to receive(:sign)
      described_class.sign(sender: sender, request: request)
      expect(Fediverse::Signature::DraftCavage12).to have_received(:sign).with(sender: sender, request: request)
    end
  end

  context 'when verifying' do
    it 'delegates to DraftCavage12' do
      allow(Fediverse::Signature::DraftCavage12).to receive(:verify)
      described_class.verify(sender: sender, request: request)
      expect(Fediverse::Signature::DraftCavage12).to have_received(:verify).with(sender: sender, request: request)
    end
  end
end
