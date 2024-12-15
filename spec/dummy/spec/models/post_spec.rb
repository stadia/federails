require 'rails_helper'

RSpec.describe Post, type: :model do
  let!(:instance) { FactoryBot.create :post }

  describe '#to_activitypub_object' do
    it 'returns a hash' do
      expect(instance.to_activitypub_object).to be_a Hash
    end
  end

  describe '.handle_incoming_fediverse_data' do
    let(:note_hash) do
      {
        'id'           => 'https://example.com/a_note',
        'type'         => 'Note',
        'content'      => 'Note content',
        'attributedTo' => distant_actor.federated_url,
      }
    end

    let(:activity_hash) do
      {
        '@context' => 'https://www.w3.org/ns/activitystreams',
        'id'       => 'https://example.com/some_activity',
        'type'     => type,
        'actor'    => distant_actor.federated_url,
        'object'   => note_hash['id'],
      }
    end

    before do
      allow(Fediverse::Request).to receive(:dereference).with(activity_hash['id']).and_return(activity_hash).once
      allow(Fediverse::Request).to receive(:dereference).with(a_kind_of(Hash)).and_call_original
      allow(Fediverse::Request).to receive(:dereference).with(note_hash['id']).and_return(note_hash).once
      allow(Federails::Actor).to receive(:find_by_federation_url).with(distant_actor.federated_url).and_return(distant_actor).once
    end

    context 'with a "Create" type' do
      let(:type) { 'Create' }
      let(:distant_actor) { FactoryBot.create :distant_actor }

      it 'creates the Post' do
        expect(described_class.handle_incoming_fediverse_data(activity_hash)).to be_a described_class
      end

      it 'does not create a new actor' do
        expect { described_class.handle_incoming_fediverse_data(activity_hash) }.not_to change(Federails::Actor, :count)
      end

      context 'when actor does not exist' do
        let(:distant_actor) { FactoryBot.build :distant_actor }

        it 'creates the actor' do
          expect { described_class.handle_incoming_fediverse_data(activity_hash) }.to change(Federails::Actor, :count).by 1
        end
      end
    end

    context 'with an "Update" type' do
      let(:type) { 'Update' }
      let(:distant_actor) { FactoryBot.create :distant_actor }

      context 'when Post already exists' do # rubocop:disable RSpec/MultipleMemoizedHelpers
        let!(:post) { FactoryBot.create :post, :distant, federated_url: note_hash['id'], federails_actor: distant_actor }

        it 'updates the Post' do
          described_class.handle_incoming_fediverse_data(activity_hash)
          post.reload

          expect(post.content).to eq note_hash['content']
        end

        it 'does not create a new post' do
          expect { described_class.handle_incoming_fediverse_data(activity_hash) }.not_to change(described_class, :count)
        end

        it 'does not create a new actor' do
          expect { described_class.handle_incoming_fediverse_data(activity_hash) }.not_to change(Federails::Actor, :count)
        end
      end

      context 'when the Post does not exist' do
        it 'creates the post' do
          post = nil
          aggregate_failures do
            expect { post = described_class.handle_incoming_fediverse_data(activity_hash) }.to change(described_class, :count).by 1
            expect(post.content).to eq note_hash['content']
          end
        end

        context 'when the actor exists' do # rubocop:disable RSpec/NestedGroups
          it 'does not create a new actor' do
            expect { described_class.handle_incoming_fediverse_data(activity_hash) }.not_to change(Federails::Actor, :count)
          end
        end

        context 'when the actor does not exist' do # rubocop:disable RSpec/NestedGroups
          let(:distant_actor) { FactoryBot.build :distant_actor }

          it 'creates the actor' do
            expect { described_class.handle_incoming_fediverse_data(activity_hash) }.to change(Federails::Actor, :count).by 1
          end
        end
      end
    end
  end

  describe 'Federails integration' do
    describe 'when creating a post' do
      it 'creates a "create" a activity' do
        expect { FactoryBot.create :post }.to change { Federails::Activity.where(action: 'Create').count }.by 1
      end
    end

    describe 'when updating a post' do
      it 'creates an "update" activity' do
        expect { instance.update! title: 'New title' }
          .to change { Federails::Activity.where(action: 'Update').count }.by(1)
          .and change { Federails::Activity.where(action: 'Create').count }.by(0) # rubocop:disable RSpec/ChangeByZero
      end
    end
  end
end
