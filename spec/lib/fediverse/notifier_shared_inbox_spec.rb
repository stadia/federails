require 'rails_helper'
require 'fediverse/notifier'

module Fediverse
  FakeEntity = Struct.new(:federated_url)
  FakeActivity = Struct.new(:id, :actor, :recipients, :action, :entity, :to, :cc, :bto, :bcc, :audience)

  RSpec.describe Notifier do
    let(:local_actor) { FactoryBot.create(:user).federails_actor }

    describe 'shared inbox deduplication' do
      let(:shared_inbox) { 'https://example.com/inbox' }
      let(:first_shared_inbox_actor) { FactoryBot.create :distant_actor, shared_inbox_url: shared_inbox }
      let(:second_shared_inbox_actor) { FactoryBot.create :distant_actor, shared_inbox_url: shared_inbox }

      let(:fake_activity) do
        FakeActivity.new(
          id: 1,
          actor: local_actor,
          to: [first_shared_inbox_actor.federated_url, second_shared_inbox_actor.federated_url],
          cc: nil, bto: nil, bcc: nil, audience: nil,
          action: 'Create',
          entity: FakeEntity.new('some_url')
        )
      end

      it 'delivers only once to a shared inbox used by multiple actors' do
        allow(described_class).to receive(:post_to_inbox).and_return(
          instance_double(Faraday::Response, status: 200, body: '')
        )
        described_class.post_to_inboxes(fake_activity)
        expect(described_class).to have_received(:post_to_inbox)
          .with(hash_including(inbox_url: shared_inbox)).once
      end
    end

    describe 'fallback to personal inbox' do
      let(:actor_without_shared) { FactoryBot.create :distant_actor, shared_inbox_url: nil }

      let(:fake_activity) do
        FakeActivity.new(
          id: 1,
          actor: local_actor,
          to: [actor_without_shared.federated_url],
          cc: nil, bto: nil, bcc: nil, audience: nil,
          action: 'Create',
          entity: FakeEntity.new('some_url')
        )
      end

      it 'falls back to personal inbox when shared_inbox_url is nil' do
        allow(described_class).to receive(:post_to_inbox).and_return(
          instance_double(Faraday::Response, status: 200, body: '')
        )
        described_class.post_to_inboxes(fake_activity)
        expect(described_class).to have_received(:post_to_inbox)
          .with(hash_including(inbox_url: actor_without_shared.inbox_url)).once
      end
    end
  end
end
