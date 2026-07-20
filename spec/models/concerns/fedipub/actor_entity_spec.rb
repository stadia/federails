require 'rails_helper'

module Federails
  RSpec.describe ActorEntity do
    describe '#acts_as_federails_actor' do
      it 'sets the class configuration in the Federails configuration' do
        aggregate_failures do
          expect(Federails::Configuration.actor_types).to have_key 'Fixtures::Classes::FakeUserModel'
          expect(Federails::Configuration.actor_types).to have_key 'Fixtures::Classes::FakeUserModelWithoutAutoCreation'
        end
      end

      context 'when not called in model' do
        it 'raises an error when accessing entity configuration' do
          instance = Fixtures::Classes::FakeUserModelWithoutConfig.new email: Faker::Internet.unique.email
          expect { instance.save }.to raise_error(/Entity not configured/)
        end
      end
    end

    describe 'hooks' do
      describe 'after_create: create_federails_actor' do
        context 'with default values' do
          let(:instance) { Fixtures::Classes::FakeUserModel.new email: Faker::Internet.unique.email }

          it 'creates an actor' do
            expect { instance.save! }.to change(Federails::Actor, :count).by 1
          end
        end

        context 'with a supplied actor' do
          let!(:actor) { FactoryBot.create :distant_actor }
          let(:instance) { Fixtures::Classes::FakeUserModelWithoutAutoCreation.new email: Faker::Internet.unique.email, federails_actor: actor }

          it 'does not create an actor' do
            expect { instance.save! }.not_to change(Federails::Actor, :count)
          end

          it 'associates existing actor' do
            instance.save!
            expect(instance.federails_actor).to eq actor
          end
        end

        context 'without actor auto-creation' do
          let(:instance) { Fixtures::Classes::FakeUserModelWithoutAutoCreation.new email: Faker::Internet.unique.email }

          it 'does not create an actor' do
            expect { instance.save! }.not_to change(Federails::Actor, :count)
          end
        end
      end

      describe '.before_destroy' do
        context 'when ActorEntity has an associated actor' do
          let(:instance) { Fixtures::Classes::FakeUserModel.create! email: Faker::Internet.unique.email }

          it 'marks the actor as tombstoned' do
            actor = instance.federails_actor
            instance.destroy!
            expect(actor.reload).to be_tombstoned
          end
        end

        context 'when ActorEntity does not have an associated actor' do
          let(:instance) { Fixtures::Classes::FakeUserModel.create! email: Faker::Internet.unique.email }

          before do
            instance.federails_actor.destroy!
            instance.reload
          end

          it 'only deletes the ActorEntity' do
            expect { instance.destroy! }.to change(Fixtures::Classes::FakeUserModel, :count).by(-1)
          end
        end
      end
    end
  end
end
