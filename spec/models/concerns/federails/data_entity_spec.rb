require 'rails_helper'

module Federails
  RSpec.describe DataEntity do
    let(:user) { FactoryBot.create :user }

    describe '#federated_url' do
      let(:instance) { Fixtures::Classes::FakeDataModel.create! federails_actor: user.federails_actor, title: 'abc', content: 'def' }

      context 'when present' do
        before do
          instance.update! federated_url: 'http://example.com/notes/123'
        end

        it 'returns the record value' do
          expect(instance.federated_url).to eq 'http://example.com/notes/123'
        end
      end

      context 'when absent' do
        it 'generates a value from the configured route' do
          expect(instance.federated_url).to eq Federails::Engine.routes.url_helpers.server_published_url(publishable_type: 'fake_data', id: instance.id)
        end
      end
    end

    describe '#acts_as_federails_data' do
      it 'sets the class configuration in the Federails configuration' do
        expect(Federails::Configuration.data_types).to have_key 'Fixtures::Classes::FakeDataModel'
      end
    end

    describe 'scopes' do
      before do
        2.times do
          Fixtures::Classes::FakeArticleDataModel.create! title: 'title', content: 'content', user: user
        end
        Fixtures::Classes::FakeArticleDataModel.create! federails_actor: FactoryBot.create(:distant_actor), federated_url: 'https://somewhere/the_note', title: 'title', content: 'content'
      end

      describe '.local_federails_entities' do
        it 'returns only local entities' do
          expect(Fixtures::Classes::FakeArticleDataModel.local_federails_entities.count).to eq 2
        end
      end

      describe '.distant_federails_entities' do
        it 'returns only distant entities' do
          expect(Fixtures::Classes::FakeArticleDataModel.distant_federails_entities.count).to eq 1
        end
      end
    end

    describe 'hooks' do
      describe 'after_create: create_federails_activity' do
        context 'with default values' do
          let(:instance) { Fixtures::Classes::FakeDataModel.new FactoryBot.attributes_for(:post, user_id: user.id) }

          it 'creates an activity' do
            expect { instance.save! }.to change(Federails::Activity.where(action: 'Create'), :count).by 1
          end
        end
      end

      describe 'after_update: create_federails_activity' do
        context 'with default values' do
          let(:instance) { Fixtures::Classes::FakeDataModel.create! FactoryBot.attributes_for(:post, user_id: user.id) }

          it 'creates an activity' do
            expect { instance.update! title: 'New title' }.to change(Federails::Activity.where(action: 'Update'), :count).by 1
          end
        end
      end

      describe 'after_delete: create_federails_activity' do
        context 'with default values' do
          let(:instance) { Fixtures::Classes::FakeDataModel.create! FactoryBot.attributes_for(:post, user_id: user.id) }

          it 'creates an activity' do
            expect { instance.destroy! }.to change(Federails::Activity.where(action: 'Delete'), :count).by 1
          end
        end
      end
    end

    describe 'Inbox hook' do
      it 'successfully defines an Inbox hook for incoming Create activities' do
        allow(Fixtures::Classes::FakeDataModel).to receive(:handle_incoming_fediverse_data)

        Fediverse::Inbox.dispatch_request 'type' => 'Create', 'object' => { 'type' => 'TestThing' }
        Fediverse::Inbox.dispatch_request 'type' => 'Create', 'object' => { 'type' => 'OtherThing' }

        expect(Fixtures::Classes::FakeDataModel).to have_received(:handle_incoming_fediverse_data).once
      end

      it 'successfully defines an Inbox hook for incoming Update activities' do
        allow(Fixtures::Classes::FakeDataModel).to receive(:handle_incoming_fediverse_data)

        Fediverse::Inbox.dispatch_request 'type' => 'Update', 'object' => { 'type' => 'TestThing' }
        Fediverse::Inbox.dispatch_request 'type' => 'Update', 'object' => { 'type' => 'OtherThing' }

        expect(Fixtures::Classes::FakeDataModel).to have_received(:handle_incoming_fediverse_data).once
      end
    end
  end
end
