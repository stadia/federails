require 'rails_helper'

module Federails
  RSpec.describe Following, type: :model do
    context 'with a follow relationship in place' do
      let(:actor) { FactoryBot.create(:user).actor }
      let(:other_actor) { FactoryBot.create(:user).actor }
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
        # auto_accept is set up as our callback method
        allow(target).to receive(:accept_follow)
        described_class.create actor: user.actor, target_actor: target.actor
        expect(target).to have_received(:accept_follow).once
      end
    end
  end
end
