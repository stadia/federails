require 'rails_helper'
require 'fediverse/inbox'
require 'fediverse/request'

module Fediverse
  RSpec.describe Inbox do
    let(:actor) { FactoryBot.create(:user).federails_actor }
    let(:distant_actor) { FactoryBot.create :distant_actor }

    describe '#handle_create_follow_request' do
      let(:distant_following) do
        {
          'id'     => 'http://example.com/fake_following_request',
          'actor'  => actor.federated_url,
          'object' => distant_actor.federated_url,
        }
      end

      it 'creates the following' do
        expect do
          described_class.send(:handle_create_follow_request, distant_following)
        end.to change(Federails::Following, :count).by 1
      end
    end

    describe '#handle_accept_request' do
      let(:local_following) { Federails::Following.create actor: actor, target_actor: distant_actor }
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
        described_class.send(:handle_accept_request, payload)

        local_following.reload
        expect(local_following).to be_accepted
      end
    end

    describe '#handle_create_note' do
      let(:distant_note) do
        {
          'id'           => 'http://example.com/fake_note',
          'attributedTo' => distant_actor.federated_url,
          'content'      => 'Some content',
        }
      end

      it 'creates a new note' do
        skip 'Note are not implemented yet'

        expect do
          described_class.send(:handle_create_note, distant_note)
        end.to change(Note, :count).by 1
      end
    end

    describe '#handle_undo_request' do
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
        let(:local_following) { Federails::Following.create actor: actor, target_actor: distant_actor }

        it 'destroys the target Following' do
          expect do
            described_class.send(:handle_undo_request, payload)
          end.to change(Federails::Following, :count).by(-1)
        end
      end

      context 'with an accepted following' do
        let(:local_following) { Federails::Following.create actor: actor, target_actor: distant_actor, status: :accepted }

        it 'destroys the target Following' do
          expect do
            described_class.send(:handle_undo_request, payload)
          end.to change(Federails::Following, :count).by(-1)
        end
      end
    end
  end
end
