require 'rails_helper'
require 'fediverse/inbox'
require 'fediverse/inbox/delete_handler'

module Fediverse
  class Inbox
    RSpec.describe DeleteHandler do
      let(:local_actor) { FactoryBot.create(:user).federails_actor }
      let(:distant_actor) { FactoryBot.create :distant_actor }

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
          let!(:entity) do
            Fixtures::Classes::FakeArticleDataModel.create!(
              federails_actor_id: distant_actor.id,
              federated_url:      'https://example.com/data/1',
              title:              'A title',
              content:            'the content'
            )
          end

          it 'triggers the "on_federails_delete_requested"' do
            expect { described_class.handle_delete_request(payload) }.to raise_error('on_federails_delete_requested called')
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

            described_class.handle_delete_request(payload)
            expect(Federails::Utils::Actor).to have_received(:tombstone!).once
          end
        end
      end

      describe '#handle_undelete_request' do
        context 'with a DataEntity' do
          let(:entity) do
            Fixtures::Classes::FakeArticleDataModel.create!(
              federails_actor_id: distant_actor.id,
              federated_url:      'https://example.com/data/1',
              title:              'A title',
              content:            'the content',
              deleted_at:         Time.current
            )
          end

          let!(:payload) do
            {
              'type'   => 'Undo',
              'actor'  => entity.federails_actor.federated_url,
              'object' => 'https://example.com/activities/delete_123',
            }
          end

          it 'triggers the "on_federails_undelete_requested" callback' do
            allow(Fediverse::Request).to receive(:dereference)
              .with(payload['object'])
              .and_return({ 'type' => 'Delete', 'id' => payload['object'], 'object' => entity.federated_url }).once

            expect { described_class.handle_undelete_request(payload) }.to raise_error('on_federails_undelete_requested called')
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
            allow(Fediverse::Request).to receive(:dereference)
              .with(payload['object'])
              .and_return({ 'type' => 'Delete', 'id' => payload['object'], 'object' => entity.federated_url }).once
            allow(Federails::Utils::Actor).to receive(:untombstone!)

            described_class.handle_undelete_request(payload)
            expect(Federails::Utils::Actor).to have_received(:untombstone!).once
          end
        end

        it 'returns without raising when the delete activity cannot be dereferenced' do
          payload = {
            'type'   => 'Undo',
            'actor'  => distant_actor.federated_url,
            'object' => 'https://example.com/activities/missing-delete',
          }

          allow(Fediverse::Request).to receive(:dereference).with(payload['object']).and_return(nil)

          expect { described_class.handle_undelete_request(payload) }.not_to raise_error
        end
      end
    end
  end
end
