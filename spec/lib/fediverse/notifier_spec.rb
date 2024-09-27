require 'rails_helper'
require 'fediverse/notifier'

module Fediverse
  FakeEntity = Struct.new :federated_url
  FakeActivity = Struct.new :id, :actor, :recipients, :action, :entity, keyword_init: true

  RSpec.describe Notifier do
    let(:local_actor) { FactoryBot.create(:user).actor }
    let(:distant_target_actor) { FactoryBot.create :distant_actor }

    describe '#post_to_inboxes' do
      context 'when notifying distant actor' do
        let(:fake_entity) { FakeEntity.new('some_url') }
        let(:fake_activity) { FakeActivity.new(id: 1, actor: local_actor, recipients: [distant_target_actor], action: 'Create', entity: fake_entity) }

        it 'sends the activity payload' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
          allow(Faraday).to receive :post

          described_class.post_to_inboxes fake_activity

          expect(Faraday).to have_received(:post) do |url, _content, headers|
            expect(url).to eq distant_target_actor.inbox_url
            expect(headers['Accept']).to eq 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"'
            expect(headers['Content-Type']).to eq 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"'
          end
        end
      end
    end
  end
end
