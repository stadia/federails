require 'rails_helper'
require 'fediverse/inbox'
require 'fediverse/request'

module Fediverse
  RSpec.describe Inbox do
    let(:local_actor) { FactoryBot.create(:user).federails_actor }
    let(:distant_actor) { FactoryBot.create :distant_actor }

    describe 'registered handlers' do
      let(:handlers) { described_class.class_variable_get :@@handlers }

      it 'registered a handler for all "Follow" activities' do
        expect(handlers['Follow']['*'].keys).to include described_class
      end

      it 'registered a handler for "Accept" activities on "Follow" object' do
        expect(handlers['Accept']['Follow'].keys).to include described_class
      end

      it 'registered a handler for "Reject" activities on "Follow" object' do
        expect(handlers['Reject']['Follow'].keys).to include described_class
      end

      it 'registered a handler for "Undo" activities on "Follow" object' do
        expect(handlers['Undo']['Follow'].keys).to include described_class
      end

      it 'registered a handler for "Delete" activities on all activities' do
        expect(handlers['Delete']['*'].keys).to include described_class
      end

      it 'registered a handler for "Undo" activities on "Delete" activities' do
        expect(handlers['Undo']['Delete'].keys).to include described_class
      end
    end

    describe '#handle_create_follow_request' do
      let(:distant_following) do
        {
          'id'     => 'http://example.com/fake_following_request',
          'actor'  => local_actor.federated_url,
          'object' => distant_actor.federated_url,
        }
      end

      it 'creates the following' do
        expect do
          described_class.send(:handle_create_follow_request, distant_following)
        end.to change(Federails::Following, :count).by 1
      end

      it 'treats duplicate follow requests as idempotent' do
        described_class.send(:handle_create_follow_request, distant_following)

        expect do
          described_class.send(:handle_create_follow_request, distant_following)
        end.not_to change(Federails::Following, :count)
      end
    end

    describe '#handle_accept_follow_request' do
      let(:local_following) { Federails::Following.create actor: local_actor, target_actor: distant_actor }
      let(:payload) do
        {
          'actor' => distant_actor.federated_url,
        }
      end
      let(:following) do
        {
          'type'   => 'Follow',
          'actor'  => local_following.actor.federated_url,
          'object' => local_following.target_actor.federated_url,
        }
      end

      it 'accepts the following request' do
        allow(Fediverse::Request).to receive(:dereference).and_return following
        described_class.send(:handle_accept_follow_request, payload)

        local_following.reload
        expect(local_following).to be_accepted
      end
    end

    describe '#handle_undo_follow_request' do
      let(:payload) do
        {
          'object' => following,
        }
      end
      let(:following) do
        {
          'type'   => 'Follow',
          'actor'  => local_following.actor.federated_url,
          'object' => local_following.target_actor.federated_url,
        }
      end

      before do
        allow(Fediverse::Request).to receive(:get).and_return following
      end

      context 'with a pending following' do
        let(:local_following) { Federails::Following.create actor: local_actor, target_actor: distant_actor }

        it 'destroys the target Following' do
          expect do
            described_class.send(:handle_undo_follow_request, payload)
          end.to change(Federails::Following, :count).by(-1)
        end
      end

      context 'with an accepted following' do
        let(:local_following) { Federails::Following.create actor: local_actor, target_actor: distant_actor, status: :accepted }

        it 'destroys the target Following' do
          expect do
            described_class.send(:handle_undo_follow_request, payload)
          end.to change(Federails::Following, :count).by(-1)
        end
      end
    end

    describe '.dispatch_request' do
      let(:payload) do
        {
          'id'     => 'http://example.com/activities/1',
          'type'   => 'Follow',
          'actor'  => local_actor.federated_url,
          'object' => distant_actor.federated_url,
        }
      end

      before do
        allow(Fediverse::Request).to receive(:dereference) { |url| { 'id' => url, 'type' => 'Person' } }
      end

      context 'when the activity has not been seen before' do
        it 'processes the activity' do
          expect { described_class.dispatch_request(payload) }.to change(Federails::Following, :count).by(1)
        end

        it 'records the federated_url on the created activity' do
          described_class.dispatch_request(payload)
          expect(Federails::Activity.find_by(federated_url: 'http://example.com/activities/1')).to be_present
        end
      end

      context 'when the activity has already been processed' do
        before do
          described_class.dispatch_request(payload)
        end

        it 'returns :duplicate' do
          expect(described_class.dispatch_request(payload)).to eq(:duplicate)
        end

        it 'does not process the activity again' do
          expect { described_class.dispatch_request(payload) }.not_to change(Federails::Following, :count)
        end
      end

      context 'when a Delete activity has already been processed' do
        let!(:distant_actor_for_delete) { FactoryBot.create :distant_actor }
        let(:delete_payload) do
          {
            'id'     => 'http://example.com/activities/delete_1',
            'type'   => 'Delete',
            'actor'  => distant_actor_for_delete.federated_url,
            'object' => distant_actor_for_delete.federated_url,
          }
        end

        before do
          allow(Federails::Utils::Actor).to receive(:tombstone!)
          described_class.dispatch_request(delete_payload)
        end

        it 'returns :duplicate for the same Delete activity' do
          expect(described_class.dispatch_request(delete_payload)).to eq(:duplicate)
        end

        it 'records the delete federated_url on a stored activity' do
          activity = Federails::Activity.find_by(federated_url: delete_payload['id'])
          expect(activity).to be_present
          expect(activity.action).to eq('Delete')
        end
      end

      context 'when receiving an Update with no actor' do
        let(:payload) do
          {
            'id'     => 'https://evil.com/activities/3',
            'type'   => 'Update',
            'object' => {
              'id'      => 'https://example.com/posts/1',
              'type'    => 'Note',
              'content' => 'hacked content',
            },
          }
        end

        it 'rejects the update' do
          expect(described_class.dispatch_request(payload)).to be(false)
        end
      end

      context 'when receiving an unauthorized Update activity' do
        let(:payload) do
          {
            'id'     => 'https://evil.com/activities/1',
            'type'   => 'Update',
            'actor'  => 'https://evil.com/users/attacker',
            'object' => {
              'id'      => 'https://example.com/posts/1',
              'type'    => 'Note',
              'content' => 'hacked content',
            },
          }
        end

        it 'rejects the update' do
          expect(described_class.dispatch_request(payload)).to be(false)
        end
      end

      context 'when receiving an Update with missing object id but actor present' do
        let(:payload) do
          {
            'id'     => 'https://evil.com/activities/2',
            'type'   => 'Update',
            'actor'  => 'https://evil.com/users/attacker',
            'object' => {
              'type'    => 'Note',
              'content' => 'hacked content',
            },
          }
        end

        it 'rejects the update' do
          expect(described_class.dispatch_request(payload)).to be(false)
        end
      end

      context 'when receiving an Update with matching origin but no handler' do
        let(:payload) do
          {
            'id'     => 'https://example.com/activities/1',
            'type'   => 'Update',
            'actor'  => 'https://example.com/users/author',
            'object' => {
              'id'      => 'https://example.com/posts/1',
              'type'    => 'Note',
              'content' => 'updated content',
            },
          }
        end

        before do
          allow(described_class).to receive(:get_handlers).and_return({})
        end

        it 'falls through as unhandled instead of being rejected by origin check' do
          expect(described_class.dispatch_request(payload)).to be(false)
        end
      end

      context 'when the payload has no id' do
        let(:payload) do
          {
            'type'   => 'Follow',
            'actor'  => local_actor.federated_url,
            'object' => distant_actor.federated_url,
          }
        end

        it 'processes the activity normally' do
          expect { described_class.dispatch_request(payload) }.to change(Federails::Following, :count).by(1)
        end
      end
    end

    describe '#handle_delete_request' do
      context 'with a DataEntity' do
        let(:payload) do
          {
            'type'   => 'Delete',
            'actor'  => entity.federails_actor.federated_url,
            'object' => entity.federated_url,
            'delete' => Time.current,
          }
        end
        let!(:entity) { Fixtures::Classes::FakeArticleDataModel.create! federails_actor_id: distant_actor.id, federated_url: 'https://example.com/data/1', title: 'A title', content: 'the content' }

        it 'triggers the "on_federails_delete_requested"' do
          expect { described_class.send(:handle_delete_request, payload) }.to raise_error 'on_federails_delete_requested called'
        end
      end

      context 'with an Actor' do
        let!(:entity) { FactoryBot.create :distant_actor }
        let(:payload) do
          {
            'type'   => 'Delete',
            'actor'  => entity.federated_url,
            'object' => entity.federated_url,
            'delete' => Time.current,
          }
        end

        it 'triggers the "on_federails_delete_requested"' do
          allow(Federails::Utils::Actor).to receive(:tombstone!)

          described_class.send(:handle_delete_request, payload)
          expect(Federails::Utils::Actor).to have_received(:tombstone!).once
        end
      end
    end

    describe '#handle_undelete_request' do
      context 'with a DataEntity' do
        let(:entity) do
          Fixtures::Classes::FakeArticleDataModel.create! federails_actor_id: distant_actor.id,
                                                          federated_url:      'https://example.com/data/1',
                                                          title:              'A title',
                                                          content:            'the content',
                                                          deleted_at:         Time.current
        end

        let!(:payload) do
          {
            'type'   => 'Undo',
            'actor'  => entity.federails_actor.federated_url,
            'object' => 'https://example.com/activities/delete_123',
          }
        end

        it 'triggers the "on_federails_undelete_requested" callback' do
          allow(Fediverse::Request).to receive(:dereference).with(payload['object']).and_return({ 'type' => 'Delete', 'id' => payload['object'], 'object' => entity.federated_url }).once

          expect { described_class.send(:handle_undelete_request, payload) }.to raise_error 'on_federails_undelete_requested called'
        end
      end

      context 'with an Actor' do
        let(:entity) { FactoryBot.create :distant_actor, tombstoned_at: Time.current }

        let!(:payload) do
          {
            'type'   => 'Undo',
            'actor'  => entity.federated_url,
            'object' => 'https://example.com/activities/delete_123',
          }
        end

        it 'triggers the "on_federails_undelete_requested" callback' do
          allow(Fediverse::Request).to receive(:dereference).with(payload['object']).and_return({ 'type' => 'Delete', 'id' => payload['object'], 'object' => entity.federated_url }).once
          allow(Federails::Utils::Actor).to receive(:untombstone!)

          described_class.send(:handle_undelete_request, payload)
          expect(Federails::Utils::Actor).to have_received(:untombstone!).once
        end
      end
    end

    describe '#handle_reject_follow_request' do
      let!(:pending_following) { Federails::Following.create actor: local_actor, target_actor: distant_actor }
      let(:payload) do
        {
          'actor'  => distant_actor.federated_url,
          'object' => 'https://example.com/follows/1',
        }
      end
      let(:follow_object) do
        {
          'type'   => 'Follow',
          'actor'  => pending_following.actor.federated_url,
          'object' => pending_following.target_actor.federated_url,
        }
      end

      before do
        allow(Fediverse::Request).to receive(:dereference).with(payload['object']).and_return(follow_object)
      end

      it 'destroys the pending following' do
        expect do
          described_class.send(:handle_reject_follow_request, payload)
        end.to change(Federails::Following, :count).by(-1)
      end

      it 'does not raise when no matching following exists' do
        pending_following.destroy

        expect do
          described_class.send(:handle_reject_follow_request, payload)
        end.not_to raise_error
      end

      it 'does not destroy an accepted following' do
        pending_following.update!(status: :accepted)

        expect do
          described_class.send(:handle_reject_follow_request, payload)
        end.not_to change(Federails::Following, :count)

        expect(pending_following.reload).to be_accepted
      end

      context 'when the activity actor is not the target of the follow' do
        let(:other_actor) { FactoryBot.create :distant_actor }
        let(:payload) do
          {
            'actor'  => other_actor.federated_url,
            'object' => 'https://example.com/follows/1',
          }
        end

        it 'raises an error' do
          expect do
            described_class.send(:handle_reject_follow_request, payload)
          end.to raise_error 'Follow not rejected by target actor but by someone else'
        end
      end
    end

    describe '.maybe_forward' do
      let(:local_follower_actor) { FactoryBot.create(:user).federails_actor }

      before do
        Federails::Following.create! actor: local_follower_actor, target_actor: local_actor, status: :accepted
      end

      context 'when activity references a local collection and local object' do
        let(:payload) do
          {
            'id'     => 'https://remote.example/activities/forward-test',
            'type'   => 'Create',
            'actor'  => distant_actor.federated_url,
            'cc'     => [local_actor.followers_url],
            'object' => {
              'id'        => 'https://remote.example/replies/1',
              'type'      => 'Note',
              'inReplyTo' => local_actor.federated_url,
            },
          }
        end

        it 'forwards the activity' do
          allow(Fediverse::Notifier).to receive(:forward_activity)

          described_class.maybe_forward(payload)

          expect(Fediverse::Notifier).to have_received(:forward_activity).once
        end
      end

      context 'when activity references a local collection but no local object' do
        let(:payload) do
          {
            'id'     => 'https://remote.example/activities/no-local-object',
            'type'   => 'Create',
            'actor'  => distant_actor.federated_url,
            'cc'     => [local_actor.followers_url],
            'object' => {
              'id'        => 'https://remote.example/notes/1',
              'type'      => 'Note',
              'inReplyTo' => 'https://remote.example/notes/0',
            },
          }
        end

        it 'does not forward the activity' do
          allow(Fediverse::Notifier).to receive(:forward_activity)

          described_class.maybe_forward(payload)

          expect(Fediverse::Notifier).not_to have_received(:forward_activity)
        end
      end

      context 'when activity does not reference a local collection' do
        let(:payload) do
          {
            'id'     => 'https://remote.example/activities/no-forward',
            'type'   => 'Create',
            'cc'     => ['https://remote.example/users/someone/followers'],
            'object' => {
              'id'        => 'https://remote.example/replies/2',
              'type'      => 'Note',
              'inReplyTo' => local_actor.federated_url,
            },
          }
        end

        it 'does not forward the activity' do
          allow(Fediverse::Notifier).to receive(:forward_activity)

          described_class.maybe_forward(payload)

          expect(Fediverse::Notifier).not_to have_received(:forward_activity)
        end
      end
    end
  end
end
