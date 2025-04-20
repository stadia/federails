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
  end
end
