require 'rails_helper'

module Federails
  RSpec.describe Following, type: :model do
    context 'with a follow relationship in place' do
      let(:actor) { FactoryBot.create(:user).federails_actor }
      let(:other_actor) { FactoryBot.create(:user).federails_actor }
      let(:following) { described_class.create actor: actor, target_actor: other_actor }

      it 'fails to create the same following twice' do
        following
        second = described_class.create actor: actor, target_actor: other_actor
        expect(second).not_to be_valid
      end
    end

    context 'when creating a follow' do
      let(:user) { FactoryBot.create :user }
      let(:target) { FactoryBot.create :user }

      it 'executes after_followed callback in target' do
        # accept_follow is set up as our callback method
        allow(target).to receive(:accept_follow)
        described_class.create actor: user.federails_actor, target_actor: target.federails_actor
        expect(target).to have_received(:accept_follow).once
      end
    end

    context 'when a follow is accepted' do
      let(:user) { FactoryBot.create :user }
      let(:target) { FactoryBot.create :user }

      it 'executes after_follow_accepted callback in target' do
        # follow_accepted is set up as our callback method
        allow(user).to receive(:follow_accepted)
        f = described_class.create actor: user.federails_actor, target_actor: target.federails_actor
        f.accept!
        expect(user).to have_received(:follow_accepted).once
      end
    end
  end
end
