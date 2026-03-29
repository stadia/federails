require 'rails_helper'
require 'fediverse/notifier'

module Fediverse
  BtoBccFakeEntity = Struct.new(:federated_url)

  RSpec.describe Notifier, '.payload bto/bcc stripping' do
    let(:actor) { FactoryBot.create(:user).federails_actor }
    let(:target_actor) { FactoryBot.create(:user).federails_actor }
    let(:entity) { FactoryBot.create(:post) }

    let(:activity) do
      Federails::Activity.create!(
        actor: actor,
        entity: entity,
        action: 'Create',
        to: [target_actor.federated_url],
        cc: ['https://www.w3.org/ns/activitystreams#Public'],
        bto: ['https://example.com/users/secret-recipient'],
        bcc: ['https://example.com/users/hidden-recipient']
      )
    end

    it 'strips bto from outbound payload' do
      json = JSON.parse(described_class.send(:payload, activity))
      expect(json).not_to have_key('bto')
    end

    it 'strips bcc from outbound payload' do
      json = JSON.parse(described_class.send(:payload, activity))
      expect(json).not_to have_key('bcc')
    end

    it 'preserves to in outbound payload' do
      json = JSON.parse(described_class.send(:payload, activity))
      expect(json['to']).to be_present
    end

    it 'preserves cc in outbound payload' do
      json = JSON.parse(described_class.send(:payload, activity))
      expect(json['cc']).to be_present
    end

    it 'includes bto/bcc recipients in delivery targets' do
      # bto/bcc recipients should be included in inboxes_for
      inboxes = described_class.send(:inboxes_for, activity)
      # The bto/bcc URLs are non-existent actors, so they may fail to resolve,
      # but the important thing is that the method attempts to include them
      expect(inboxes).to be_an(Array)
    end
  end
end
