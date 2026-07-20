require 'rails_helper'
require 'federails/utils/actor'

RSpec.describe Federails::Utils::Actor do
  describe '.tombstone!' do
    context 'with a local actor' do
      let(:actor) { FactoryBot.create :local_actor }

      it 'hardcodes all the previously computed values' do
        nils = Federails::Utils::Actor::COMPUTED_ATTRIBUTES.to_h { |k| [k.to_s, nil] }
        computed = Federails::Utils::Actor::COMPUTED_ATTRIBUTES.to_h { |k| [k.to_s, actor.send(k)] }

        expect { described_class.tombstone!(actor) }.to change { actor.attributes.slice(*Federails::Utils::Actor::COMPUTED_ATTRIBUTES.map(&:to_s)) }.from(nils).to computed
      end

      it 'does not nullify the entity if still existing' do
        described_class.tombstone!(actor)
        expect(actor.entity).not_to be_nil
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

  describe '.untombstone!' do
    before do
      actor.tombstone!
    end

    context 'with a local actor' do
      let(:actor) { FactoryBot.create :local_actor }

      context 'when actor entity does not exists anymore' do
        before do
          actor.entity.destroy!

          actor.reload
        end

        it 'raises an error' do
          expect { actor.untombstone! }.to raise_error(/^Cannot restore a local actor/)
        end
      end

      context 'when actor entity still exists' do
        it 'sets all computable values to nil' do
          nils = Federails::Utils::Actor::COMPUTED_ATTRIBUTES.to_h { |k| [k.to_s, nil] }
          computed = Federails::Utils::Actor::COMPUTED_ATTRIBUTES.to_h { |k| [k.to_s, actor.send(k)] }

          expect { described_class.untombstone!(actor) }.to change { actor.attributes.slice(*Federails::Utils::Actor::COMPUTED_ATTRIBUTES.map(&:to_s)) }.from(computed).to nils
        end

        it 'removes the tombstoned flag from actor' do
          described_class.untombstone!(actor)
          expect(actor).not_to be_tombstoned
        end

        it 'creates an Undo activity' do
          expect { described_class.untombstone!(actor) }.to change(Federails::Activity.where(action: 'Undo'), :count).by 1
        end
      end
    end

    context 'with a distant actor' do
      let(:actor) { FactoryBot.create :distant_actor, federated_url: 'https://mamot.fr/users/mtancoigne', username: 'mtancoigne', server: 'mamot.fr' }

      before do
        allow(actor).to receive(:sync!).and_return(true)
      end

      it 'does not change computed values' do
        expect { described_class.untombstone!(actor) }.not_to(change { actor.attributes.slice(*Federails::Utils::Actor::COMPUTED_ATTRIBUTES.map(&:to_s)) })
      end

      it 'syncs the actor' do
        described_class.untombstone!(actor)

        expect(actor).to have_received(:sync!).once
      end

      it 'removes the tombstoned flag from actor' do
        described_class.untombstone!(actor)

        expect(actor).not_to be_tombstoned
      end

      it 'does not create a Delete activity' do
        expect { described_class.untombstone!(actor) }.not_to change(Federails::Activity.where(action: 'Delete'), :count)
      end
    end
  end
end
