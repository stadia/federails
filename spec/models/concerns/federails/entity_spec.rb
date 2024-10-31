require 'rails_helper'

module Federails
  class FakeModel < ApplicationRecord
    self.table_name = 'users'
    include Federails::Entity

    acts_as_federails_actor
  end

  class FakeModelWithoutAutoCreation < ApplicationRecord
    self.table_name = 'users'
    include Federails::Entity

    acts_as_federails_actor auto_create_actors: false
  end

  RSpec.describe Entity do
    describe '#acts_as_federails_actor' do
      it 'sets the class configuration in the Federails configuration' do
        aggregate_failures do
          expect(Federails::Configuration.entity_types).to have_key 'Federails::FakeModel'
          expect(Federails::Configuration.entity_types).to have_key 'Federails::FakeModelWithoutAutoCreation'
        end
      end
    end

    describe 'hooks' do
      describe 'after_create: create_actor' do
        context 'with default values' do
          let(:instance) { FakeModel.new email: Faker::Internet.unique.email }

          it 'creates an actor' do
            expect { instance.save! }.to change(Federails::Actor, :count).by 1
          end
        end

        context 'without actor auto-creation' do
          let(:instance) { FakeModelWithoutAutoCreation.new email: Faker::Internet.unique.email }

          it 'does not create an actor' do
            expect { instance.save! }.not_to change(Federails::Actor, :count)
          end
        end
      end
    end
  end
end
