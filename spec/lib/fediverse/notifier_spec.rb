require 'rails_helper'
require 'fediverse/notifier'

module Fediverse
  FakeEntity = Struct.new :federated_url
  FakeActivity = Struct.new :id, :actor, :recipients, :action, :entity, :to, :cc, keyword_init: true

  RSpec.describe Notifier do
    let(:local_actor) { FactoryBot.create(:user).federails_actor }
    let(:distant_target_actor) { FactoryBot.create :distant_actor }

    describe 'delivery' do
      context 'when activity creator is distant' do
        let(:distant_actor) { FactoryBot.create :distant_actor }
        let(:activity) { FactoryBot.create :activity, actor: distant_actor }

        it 'does not notify anyone, the remote server will have done it already' do
          expect(described_class.send(:inboxes_for, activity)).to eq []
        end
      end
    end

    describe '#post_to_inboxes' do
      context 'when notifying distant actor' do
        let(:fake_entity) { FakeEntity.new('some_url') }
        let(:fake_activity) { FakeActivity.new(id: 1, actor: local_actor, to: [distant_target_actor.federated_url], action: 'Create', entity: fake_entity) }

        it 'calls post_to_inbox for each recipient' do
          allow(described_class).to receive(:post_to_inbox)
          described_class.post_to_inboxes(fake_activity)
          expect(described_class).to have_received(:post_to_inbox).with(hash_including(inbox_url: distant_target_actor.inbox_url)).once
        end
      end

      context 'when notifying a follower collection' do
        let(:fake_entity) { FakeEntity.new('some_url') }
        let(:fake_activity) { FakeActivity.new(id: 1, actor: local_actor, to: [Fediverse::Collection::PUBLIC], cc: ['https://activitypub.academy/users/begusla_laddaciul/followers'], action: 'Create', entity: fake_entity) }

        before do
          FactoryBot.create :following, actor: distant_target_actor, target_actor: local_actor
        end

        it 'calls post_to_inbox for each recipient' do
          VCR.use_cassette('fediverse/notifier/get_collection_200') do
            allow(described_class).to receive(:post_to_inbox)
            described_class.post_to_inboxes(fake_activity)
            expect(described_class).to have_received(:post_to_inbox).with(hash_including(inbox_url: 'https://3dp.chat/users/manyfold/inbox')).once
          end
        end
      end

      context 'when posting publicly but with no cc' do
        let(:fake_entity) { FakeEntity.new('some_url') }
        let(:fake_activity) { FakeActivity.new(id: 1, actor: local_actor, to: [Fediverse::Collection::PUBLIC], action: 'Create', entity: fake_entity) }

        it 'does not post to any specific inboxes' do
          allow(described_class).to receive(:post_to_inbox)
          described_class.post_to_inboxes(fake_activity)
          expect(described_class).not_to have_received(:post_to_inbox)
        end
      end
    end

    describe '#signed_request' do
      let(:request) do
        described_class.send :signed_request,
                             url:     distant_target_actor.inbox_url,
                             from:    local_actor,
                             message: 'test'
      end

      it 'posts to inbox URL' do
        # Faraday::Request#path is badly named, it's the full URL without query params
        expect(request.path).to eq distant_target_actor.inbox_url
      end

      it 'sends correct activitypub content type' do
        expect(request.headers['Content-Type']).to eq 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"'
      end

      it 'accepts correct activitypub content type' do
        expect(request.headers['Accept']).to eq 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"'
      end

      it 'adds a signature to outgoing requests' do
        expect(request.headers['Signature']).to be_present
      end

      it 'adds a verifiable signature to outgoing requests' do
        expect(Fediverse::Signature.verify(sender: local_actor, request: request)).to be_truthy
      end
    end
  end
end
