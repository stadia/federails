require 'rails_helper'

module Federails
  RSpec.describe Activity, type: :model do
    let(:actor) { FactoryBot.create :local_actor }
    let(:distant_actor) { FactoryBot.create :distant_actor }

    describe 'delivery' do
      context 'when activity creator is distant' do
        it 'does not notify actor' do
          activity = described_class.new actor: distant_actor
          expect(activity.recipients).to eq []
        end
      end
    end
  end
end
