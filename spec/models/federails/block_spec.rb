require 'rails_helper'

module Federails
  RSpec.describe Block, type: :model do
    let(:actor) { FactoryBot.create :local_actor }
    let(:target_actor) { FactoryBot.create :local_actor }

    it 'creates a valid block' do
      block = described_class.create!(actor: actor, target_actor: target_actor)
      expect(block).to be_persisted
      expect(block.actor).to eq(actor)
      expect(block.target_actor).to eq(target_actor)
    end

    it 'enforces uniqueness of actor and target_actor' do
      described_class.create!(actor: actor, target_actor: target_actor)
      expect { described_class.create!(actor: actor, target_actor: target_actor) }
        .to raise_error(ActiveRecord::RecordInvalid, /Target actor has already been taken/)
    end

    it 'allows reverse block' do
      described_class.create!(actor: actor, target_actor: target_actor)
      reverse = described_class.create!(actor: target_actor, target_actor: actor)
      expect(reverse).to be_persisted
    end
  end
end
