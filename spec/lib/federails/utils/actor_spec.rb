require 'rails_helper'
require 'federails/utils/actor'

RSpec.describe Federails::Utils::Actor do
  describe '.tombstone!', :doing do
    context 'with a local actor' do
      let(:actor) { FactoryBot.create :local_actor }

      it 'hardcodes all the previously computed values' do
        nils = Federails::Utils::Actor::COMPUTED_ATTRIBUTES.to_h { |k| [k.to_s, nil] }
        computed = Federails::Utils::Actor::COMPUTED_ATTRIBUTES.to_h { |k| [k.to_s, actor.send(k)] }

        expect { described_class.tombstone!(actor) }.to change { actor.attributes.slice(*Federails::Utils::Actor::COMPUTED_ATTRIBUTES.map(&:to_s)) }.from(nils).to computed
      end

      it 'nullifies the entity' do
        described_class.tombstone!(actor)
        expect(actor.entity).to be_nil
      end

      it 'marks the actor as tombstoned' do
        described_class.tombstone!(actor)
        expect(actor).to be_tombstoned
      end

      it 'creates a Delete activity' do
        expect { described_class.tombstone!(actor) }.to change(Federails::Activity.where(action: 'Delete'), :count).by 1
      end
    end

    context 'with a distant actor' do
      let(:actor) { FactoryBot.create :distant_actor }

      it 'does not change computed values' do
        expect { described_class.tombstone!(actor) }.not_to(change { actor.attributes.slice(*Federails::Utils::Actor::COMPUTED_ATTRIBUTES.map(&:to_s)) })
      end

      it 'marks the actor as tombstoned' do
        described_class.tombstone!(actor)
        expect(actor).to be_tombstoned
      end

      it 'does not create a Delete activity' do
        expect { described_class.tombstone!(actor) }.not_to change(Federails::Activity.where(action: 'Delete'), :count)
      end
    end
  end
end
