require 'rails_helper'

RSpec.describe Comment, type: :model do
  let!(:instance) { FactoryBot.create :comment }

  describe '#to_activitypub_object' do
    it 'returns a hash' do
      expect(instance.to_activitypub_object).to be_a Hash
    end
  end

  # rubocop:disable RSpec/MultipleMemoizedHelpers
  describe '.handle_incoming_fediverse_data' do
    # Should be a Post in the end
    let(:parent_hash) do
      {
        'id'           => 'https://example.com/initial_note',
        'type'         => 'Note',
        'content'      => 'Note content',
        'attributedTo' => distant_actor.federated_url,
      }
    end
    # Should be a Comment in the end
    let(:note_hash) do
      {
        'id'           => 'https://example.com/a_note',
        'type'         => 'Note',
        'content'      => 'Note content',
        'attributedTo' => distant_actor.federated_url,
        'inReplyTo'    => parent_hash['id'],
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
      allow(Fediverse::Request).to receive(:dereference).with(parent_hash['id']).and_return(parent_hash).twice
      allow(Federails::Actor).to receive(:find_by_federation_url).with(distant_actor.federated_url).and_return(distant_actor).twice
    end

    context 'with a "Create" type' do
      let(:type) { 'Create' }
      let(:distant_actor) { FactoryBot.create :distant_actor }

      it 'creates the Comment' do
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

      context 'when Comment already exists' do
        let!(:comment) { FactoryBot.create :comment, :distant, federated_url: note_hash['id'], federails_actor: distant_actor }

        it 'updates the Comment' do
          described_class.handle_incoming_fediverse_data(activity_hash)
          comment.reload

          expect(comment.content).to eq note_hash['content']
        end

        it 'does not create a new comment' do
          expect { described_class.handle_incoming_fediverse_data(activity_hash) }.not_to change(described_class, :count)
        end

        it 'does not create a new actor' do
          expect { described_class.handle_incoming_fediverse_data(activity_hash) }.not_to change(Federails::Actor, :count)
        end
      end

      context 'when the Comment does not exist' do
        it 'creates the comment' do
          comment = nil
          aggregate_failures do
            expect { comment = described_class.handle_incoming_fediverse_data(activity_hash) }.to change(described_class, :count).by 1
            expect(comment.content).to eq note_hash['content']
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
  # rubocop:enable RSpec/MultipleMemoizedHelpers

  describe 'Federails integration' do
    describe 'when creating a comment' do
      it 'creates a "create" a activity' do
        expect { FactoryBot.create :comment }.to change { Federails::Activity.where(action: 'Create', entity_type: 'Comment').count }.by(1)
      end
    end

    describe 'when updating a comment' do
      it 'creates an "update" activity' do
        expect { instance.update! content: 'New content' }
          .to change { Federails::Activity.where(action: 'Update').count }.by(1)
          .and change { Federails::Activity.where(action: 'Create').count }.by(0) # rubocop:disable RSpec/ChangeByZero
      end
    end
  end
end
