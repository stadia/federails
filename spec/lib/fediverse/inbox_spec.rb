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
        expect(handlers['Follow']['*'].keys).to include(Fediverse::Inbox::FollowHandler)
      end

      it 'registered a handler for "Accept" activities on "Follow" object' do
        expect(handlers['Accept']['Follow'].keys).to include(Fediverse::Inbox::FollowHandler)
      end

      it 'registered a handler for "Reject" activities on "Follow" object' do
        expect(handlers['Reject']['Follow'].keys).to include(Fediverse::Inbox::FollowHandler)
      end

      it 'registered a handler for "Undo" activities on "Follow" object' do
        expect(handlers['Undo']['Follow'].keys).to include(Fediverse::Inbox::FollowHandler)
      end

      it 'registered a handler for "Delete" activities on all activities' do
        expect(handlers['Delete']['*'].keys).to include(Fediverse::Inbox::DeleteHandler)
      end

      it 'registered a handler for "Undo" activities on "Delete" activities' do
        expect(handlers['Undo']['Delete'].keys).to include(Fediverse::Inbox::DeleteHandler)
      end

      it 'registers a built-in handler for Like activities' do
        expect(handlers['Like']['*'].keys).to include(Fediverse::Inbox::LikeHandler)
      end

      it 'registers a built-in handler for Undo Like activities' do
        expect(handlers['Undo']['Like'].keys).to include(Fediverse::Inbox::LikeHandler)
      end

      it 'registers a built-in handler for Announce activities' do
        expect(handlers['Announce']['*'].keys).to include(Fediverse::Inbox::AnnounceHandler)
      end

      it 'registers a built-in handler for Undo Announce activities' do
        expect(handlers['Undo']['Announce'].keys).to include(Fediverse::Inbox::AnnounceHandler)
      end

      it 'registers a built-in handler for Block activities' do
        expect(handlers['Block']['*'].keys).to include(Fediverse::Inbox::BlockHandler)
      end

      it 'registers a built-in handler for Undo Block activities' do
        expect(handlers['Undo']['Block'].keys).to include(Fediverse::Inbox::BlockHandler)
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

      context 'when a host app overrides a built-in handler' do
        let(:payload) do
          {
            'id'     => 'https://example.com/activities/like-1',
            'type'   => 'Like',
            'actor'  => local_actor.federated_url,
            'object' => distant_actor.federated_url,
          }
        end

        let(:custom_handler) do
          Class.new do
            class << self
              # rubocop:disable Naming/PredicateMethod
              attr_reader :received_payload

              def handle_like_activity(activity)
                @received_payload = activity
                true
              end
              # rubocop:enable Naming/PredicateMethod
            end
          end
        end

        around do |example|
          handlers = described_class.class_variable_get(:@@handlers)
          original_like_handlers = handlers['Like'].deep_dup

          described_class.register_handler('Like', '*', custom_handler, :handle_like_activity)
          example.run

          handlers['Like'] = original_like_handlers
        end

        it 'dispatches to the overriding handler' do
          expect(described_class.dispatch_request(payload)).to be true
          expect(custom_handler.received_payload).to eq(payload)
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
