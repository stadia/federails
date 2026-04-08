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

    describe '.find_untombstoned_by!' do
      let(:actor) { FactoryBot.create :local_actor }

      context 'when soft deleted and :soft_deleted_method set' do
        let!(:entity) { Fixtures::Classes::FakeArticleDataModel.create! federails_actor: actor, title: 'abc', content: 'def' }

        it 'raises an error' do
          entity.update! deleted_at: Time.current

          expect { Fixtures::Classes::FakeArticleDataModel.find_untombstoned_by! id: entity.id }.to raise_error Federails::DataEntity::TombstonedError
        end
      end

      context 'without soft delete support' do # Well, record _was_ destroyed
        it 'raises an error' do
          expect { Fixtures::Classes::FakeDataModel.find_untombstoned_by! id: 0 }.to raise_error ActiveRecord::RecordNotFound
        end
      end

      context 'when the object exists' do
        let!(:entity) { Fixtures::Classes::FakeDataModel.create! federails_actor: actor, title: 'abc', content: 'def' }

        it 'returns the object' do
          expect(Fixtures::Classes::FakeDataModel.find_untombstoned_by!(id: entity.id)).not_to be_nil
        end
      end
    end

    describe '#federails_sync!' do
      context 'with a local entity' do
        let(:actor) { FactoryBot.create :local_actor }
        let!(:entity) { Fixtures::Classes::FakeArticleDataModel.create! federails_actor: actor, title: 'abc', content: 'def' }

        it 'returns false' do
          expect(entity.federails_sync!).to be false
        end
      end

      context 'with a distant entity' do
        let(:actor) { FactoryBot.create :distant_actor, federated_url: 'https://mamot.fr/users/mtancoigne', username: 'mtancoigne', server: 'mamot.fr' }
        let!(:entity) { Fixtures::Classes::FakeArticleDataModel.create! federails_actor: actor, federated_url: 'https://mamot.fr/users/mtancoigne/statuses/113741447018463971', title: 'abc', content: 'def' }

        it 'updates the entity' do
          VCR.use_cassette 'dummy/fediverse/request/get_note_200' do
            expect { entity.federails_sync! }.to change { entity.reload.title }.from('abc').to('A post')
          end
        end

        it 'returns true' do
          VCR.use_cassette 'dummy/fediverse/request/get_note_200' do
            expect(entity.federails_sync!).to be true
          end
        end
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

    describe 'actions' do
      let(:instance) { Fixtures::Classes::FakeDataModel.create! FactoryBot.attributes_for(:post, user_id: user.id) }

      describe 'announce' do
        context 'with default values (self-announce)' do
          it 'creates an activity' do
            expect { instance.announce! }.to change(Federails::Activity.where(action: 'Announce'), :count).by 1
          end

          it 'assigns self as actor' do
            activity = instance.announce!
            expect(activity.actor).to eq instance.federails_actor
          end
        end

        context 'with a different actor' do
          let(:another_user) { FactoryBot.create :user }
          let(:actor) { another_user.federails_actor }

          it 'uses the specified actor' do
            activity = instance.announce! actor: actor
            expect(activity.actor).to eq actor
          end
        end

        describe 'like' do
          context 'with a different actor' do
            let(:another_user) { FactoryBot.create :user }
            let(:actor) { another_user.federails_actor }

            it 'creates an activity' do
              expect { instance.like! actor: actor }.to change(Federails::Activity.where(action: 'Like'), :count).by 1
            end

            it 'uses the specified actor' do
              activity = instance.like! actor: actor
              expect(activity.actor).to eq actor
            end
          end
        end

        describe 'dislike' do
          context 'with a different actor' do
            let(:another_user) { FactoryBot.create :user }
            let(:actor) { another_user.federails_actor }

            it 'creates an activity' do
              expect { instance.dislike! actor: actor }.to change(Federails::Activity.where(action: 'Dislike'), :count).by 1
            end

            it 'uses the specified actor' do
              activity = instance.dislike! actor: actor
              expect(activity.actor).to eq actor
            end
          end
        end
      end
    end
  end
end
