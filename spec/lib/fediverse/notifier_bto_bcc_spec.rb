require 'rails_helper'
require 'fediverse/notifier'

module Fediverse
  BtoBccFakeEntity = Struct.new(:federated_url)
  BtoBccFakeActivity = Struct.new(:id, :actor, :recipients, :action, :entity, :to, :cc, :bto, :bcc, :audience)

  RSpec.describe Notifier, 'bto/bcc handling' do
    let(:local_actor) { FactoryBot.create(:user).federails_actor }
    let(:bto_actor) { FactoryBot.create(:distant_actor) }
    let(:bcc_actor) { FactoryBot.create(:distant_actor) }

    let(:fake_entity) { BtoBccFakeEntity.new('some_url') }
    let(:fake_activity) do
      BtoBccFakeActivity.new(
        id: 1,
        actor: local_actor,
        to: [Fediverse::Collection::PUBLIC],
        cc: nil,
        bto: [bto_actor.federated_url],
        bcc: [bcc_actor.federated_url],
        audience: nil,
        action: 'Create',
        entity: fake_entity
      )
    end

    it 'delivers to bto/bcc recipients but strips fields from payload' do
      delivered_payloads = []
      delivered_inboxes = []

      allow(described_class).to receive(:post_to_inbox) do |inbox_url:, message:, from:|
        delivered_inboxes << inbox_url
        delivered_payloads << JSON.parse(message)
        instance_double(Faraday::Response, status: 200, body: '')
      end

      described_class.post_to_inboxes(fake_activity)

      # bto/bcc recipients should be in delivery targets
      expect(delivered_inboxes).to include(bto_actor.inbox_url)
      expect(delivered_inboxes).to include(bcc_actor.inbox_url)

      # bto/bcc should be stripped from all delivered payloads
      delivered_payloads.each do |p|
        expect(p).not_to have_key('bto')
        expect(p).not_to have_key('bcc')
      end
    end

    it 'includes bto/bcc in inboxes_for resolution' do
      inboxes = described_class.send(:inboxes_for, fake_activity)
      expect(inboxes).to include(bto_actor.inbox_url)
      expect(inboxes).to include(bcc_actor.inbox_url)
    end
  end
end
