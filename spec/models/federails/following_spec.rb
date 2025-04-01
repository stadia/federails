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
        f = described_class.create actor: user.federails_actor, target_actor: target.federails_actor
        expect(target).to have_received(:accept_follow).with(f).once
      end

      it 'executes after_follow_accepted callback in target' do
        # follow_accepted is set up as our callback method
        allow(user).to receive(:follow_accepted)
        f = described_class.create actor: user.federails_actor, target_actor: target.federails_actor
        f.accept!
        expect(user).to have_received(:follow_accepted).with(f).once
      end
    end

    context 'when following a remote actor' do
      let(:local_user) { FactoryBot.create :user }
      let(:remote_actor) { FactoryBot.create :distant_actor }

      it 'creates Follow activity' do # rubocop:disable RSpec/ExampleLength
        allow(Activity).to receive(:create!)
        described_class.create actor: local_user.federails_actor, target_actor: remote_actor
        expect(Activity).to have_received(:create!).with(
          action: 'Follow',
          actor:  local_user.federails_actor,
          entity: remote_actor
        )
      end

      it 'queues NotifyInboxJob' do
        expect do
          described_class.create actor: local_user.federails_actor, target_actor: remote_actor
        end.to have_enqueued_job(NotifyInboxJob).once
      end
    end

    context 'when unfollowing a distant actor' do
      let(:local_user) { FactoryBot.create :user }
      let(:distant_actor) { FactoryBot.create :distant_actor }
      let!(:follow) { described_class.create actor: local_user.federails_actor, target_actor: distant_actor }

      it 'creates Undo activity when Following is destroyed' do # rubocop:disable RSpec/ExampleLength
        allow(Activity).to receive(:create!)
        follow.destroy
        expect(Activity).to have_received(:create!).with(
          action: 'Undo',
          actor:  local_user.federails_actor,
          entity: Activity.find_by(action: 'Follow', actor: local_user.federails_actor, entity: distant_actor)
        )
      end

      it 'queues NotifyInboxJob' do
        expect { follow.destroy }.to have_enqueued_job(NotifyInboxJob).once
      end
    end
  end
end
