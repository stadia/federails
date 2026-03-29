require 'rails_helper'
require 'fediverse/inbox/block_handler'

RSpec.describe Fediverse::Inbox::BlockHandler do
  let(:distant_actor) { FactoryBot.create :distant_actor }
  let(:local_actor) { FactoryBot.create(:user).federails_actor }

  before do
    allow(Federails::Actor).to receive(:find_or_create_by_federation_url)
      .with(distant_actor.federated_url).and_return(distant_actor)
    allow(Federails::Actor).to receive(:find_or_create_by_federation_url)
      .with(local_actor.federated_url).and_return(local_actor)
  end

  describe '.handle_block' do
    let(:activity) do
      {
        'id'     => 'https://example.com/activities/block-1',
        'type'   => 'Block',
        'actor'  => distant_actor.federated_url,
        'object' => local_actor.federated_url,
      }
    end

    it 'creates a block record' do
      expect { described_class.handle_block(activity) }
        .to change(Federails::Block, :count).by(1)

      block = Federails::Block.last
      expect(block.actor).to eq(distant_actor)
      expect(block.target_actor).to eq(local_actor)
    end

    it 'returns true on success' do
      expect(described_class.handle_block(activity)).to be true
    end

    it 'is idempotent' do
      described_class.handle_block(activity)
      expect { described_class.handle_block(activity) }
        .not_to change(Federails::Block, :count)
    end

    context 'when followings exist' do
      before do
        Federails::Following.create!(actor: distant_actor, target_actor: local_actor)
        Federails::Following.create!(actor: local_actor, target_actor: distant_actor)
      end

      it 'destroys followings in both directions' do
        expect { described_class.handle_block(activity) }
          .to change(Federails::Following, :count).by(-2)
      end
    end
  end

  describe '.handle_undo_block' do
    let!(:block) do
      Federails::Block.create!(actor: distant_actor, target_actor: local_actor)
    end

    let(:activity) do
      {
        'id'     => 'https://example.com/activities/undo-block-1',
        'type'   => 'Undo',
        'actor'  => distant_actor.federated_url,
        'object' => {
          'type'   => 'Block',
          'actor'  => distant_actor.federated_url,
          'object' => local_actor.federated_url,
        },
      }
    end

    it 'destroys the block record' do
      expect { described_class.handle_undo_block(activity) }
        .to change(Federails::Block, :count).by(-1)
    end

    it 'returns true on success' do
      expect(described_class.handle_undo_block(activity)).to be true
    end

    it 'returns false when block not found' do
      block.destroy!
      expect(described_class.handle_undo_block(activity)).to be false
    end
  end
end
