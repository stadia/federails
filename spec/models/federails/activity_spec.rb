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

      context 'when creating a Following' do
        let(:following) { FactoryBot.create :following, actor: actor, target_actor: distant_actor }

        it 'is addressed to the target actor' do
          expect(following.follow_activity.to).to eq [distant_actor.federated_url]
        end

        it 'does not cc anyone' do
          expect(following.follow_activity.cc).to be_nil
        end
      end

      context 'when accepting a Following' do
        let(:distant_following) { FactoryBot.create :following, actor: distant_actor, target_actor: actor }
        let(:accept) { distant_following.activities.find_by(action: 'Accept') }

        before { distant_following.accept! }

        it 'is addressed to the Following creator' do
          expect(accept.to).to eq [distant_actor.federated_url]
        end

        it 'does not cc anyone' do
          expect(accept.cc).to be_nil
        end
      end

      context 'when undoing a Following' do
        let(:following) { FactoryBot.create :following, actor: actor, target_actor: distant_actor }
        let(:undo) { described_class.find_by(action: 'Undo') }

        before { following.destroy! }

        it 'is addressed to the Following creator' do
          expect(undo.to).to eq [distant_actor.federated_url]
        end

        it 'does not cc anyone' do
          expect(undo.cc).to be_nil
        end
      end
    end
  end
end
