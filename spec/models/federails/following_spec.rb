require 'rails_helper'
require 'fediverse/notifier'

module Federails
  RSpec.describe Following, type: :model do
    describe 'hooks' do
      describe 'on_federails_delete_requested' do
        it 'tombstones the actor' do
          following = FactoryBot.create :following, :incoming
          following.run_callbacks :on_federails_delete_requested

          expect { following.reload }.to raise_error ActiveRecord::RecordNotFound
        end
      end
    end

    context 'with a follow relationship in place' do
      let(:follower) { FactoryBot.create :local_actor }
      let(:target) { FactoryBot.create :local_actor }

      before do
        described_class.create! actor: follower, target_actor: target
      end

      it 'fails to create the same following twice' do
        expect { described_class.create! actor: follower, target_actor: target }.to raise_error(/Target actor has already been taken/)
      end
    end

    context 'when following a local actor' do
      let(:follower) { FactoryBot.create :local_actor }
      let(:target) { FactoryBot.create :local_actor }
      let(:following) { described_class.build actor: follower, target_actor: target }

      it 'executes after_followed callback in target' do
        # accept_follow is set up as our callback method
        allow(target.entity).to receive(:accept_follow)
        following.save!

        expect(target.entity).to have_received(:accept_follow).with(following).once
      end

      it 'executes after_follow_accepted callback in target' do
        following.save!

        # follow_accepted is set up as our callback method
        allow(follower.entity).to receive(:follow_accepted)
        following.accept!

        expect(follower.entity).to have_received(:follow_accepted).with(following).once
      end
    end

    context 'when following a remote actor' do
      let(:follower) { FactoryBot.create :local_actor }
      let(:target) { FactoryBot.create :distant_actor }
      let(:following) { described_class.build actor: follower, target_actor: target }

      it 'creates Follow activity' do # rubocop:disable RSpec/ExampleLength
        allow(Activity).to receive(:create!)
        following.save!
        expect(Activity).to have_received(:create!).with(
          action: 'Follow',
          actor:  follower,
          entity: target
        )
      end

      it 'queues NotifyInboxJob' do
        expect do
          following.save!
        end.to have_enqueued_job(NotifyInboxJob).once
      end
    end

    context 'when unfollowing a local actor' do
      let(:follower) { FactoryBot.create :local_actor }
      let(:target) { FactoryBot.create :local_actor }
      let!(:following) { described_class.create! actor: follower, target_actor: target }

      it 'creates Undo activity when Following is destroyed' do # rubocop:disable RSpec/ExampleLength
        allow(Activity).to receive(:create!)
        following.destroy!
        expect(Activity).to have_received(:create!).with(
          action: 'Undo',
          actor:  follower,
          entity: Activity.find_by(action: 'Follow', actor: follower, entity: target)
        )
      end

      it 'queues NotifyInboxJob' do
        expect { following.destroy! }.to have_enqueued_job(NotifyInboxJob).once
      end
    end

    context 'when unfollowing a distant actor' do
      let(:follower) { FactoryBot.create :local_actor }
      let(:target) { FactoryBot.create :distant_actor }

      let!(:following) { described_class.create! actor: follower, target_actor: target }

      it 'creates Undo activity when Following is destroyed' do # rubocop:disable RSpec/ExampleLength
        allow(Activity).to receive(:create!)
        following.destroy!
        expect(Activity).to have_received(:create!).with(
          action: 'Undo',
          actor:  follower,
          entity: Activity.find_by(action: 'Follow', actor: follower, entity: target)
        )
      end

      it 'queues NotifyInboxJob' do
        expect { following.destroy! }.to have_enqueued_job(NotifyInboxJob).once
      end
    end

    context 'when a remote actor follows a local user' do
      let(:follower) { FactoryBot.create :distant_actor }
      let(:target) { FactoryBot.create :local_actor }

      let(:following) { described_class.build actor: follower, target_actor: target }

      it 'does not create Follow activity' do
        expect do
          following.save!
        end.not_to change(Activity, :count)
      end

      it 'does not queue NotifyInboxJob' do
        expect do
          following.save!
        end.not_to have_enqueued_job(NotifyInboxJob)
      end
    end

    context 'when a remote actor unfollows a local user' do
      let(:follower) { FactoryBot.create :distant_actor }
      let(:target) { FactoryBot.create :local_actor }
      let!(:following) { described_class.create! actor: follower, target_actor: target }

      it 'does not create Follow activity' do
        expect { following.destroy! }.not_to change(Activity, :count)
      end

      it 'does not queue NotifyInboxJob' do
        expect { following.destroy! }.not_to have_enqueued_job(NotifyInboxJob)
      end
    end
  end
end
