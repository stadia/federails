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
        following.accept!(follow_activity: following.follow_activity)

        expect(follower.entity).to have_received(:follow_accepted).with(following).once
      end
    end

    context 'when following a remote actor' do
      let(:follower) { FactoryBot.create :local_actor }
      let(:target) { FactoryBot.create :distant_actor }
      let(:following) { described_class.create actor: follower, target_actor: target }
      let!(:activity) { following.follow_activity }

      it 'creates activity with Follow action' do
        expect(activity.action).to eq 'Follow'
      end

      it 'creates Follow activity with the follower as the actor' do
        expect(activity.actor).to eq follower
      end

      it 'creates Follow activity with the target as the entity' do
        expect(activity.entity).to eq target
      end

      it 'is addressed to the target actor' do
        expect(activity.to).to eq [target.federated_url]
      end

      it 'does not cc anyone' do
        expect(activity.cc).to be_nil
      end

      it 'queues NotifyInboxJob' do
        expect(NotifyInboxJob).to have_been_enqueued.with(activity)
      end
    end

    context 'when unfollowing a local actor' do
      let(:follower) { FactoryBot.create :local_actor }
      let(:target) { FactoryBot.create :local_actor }
      let(:following) { described_class.create! actor: follower, target_actor: target }
      let!(:activity) do
        following.destroy!
        Activity.find_by(action: 'Undo')
      end

      it 'creates activity with Undo action' do
        expect(activity.action).to eq 'Undo'
      end

      it 'creates Undo activity with the follower as the actor' do
        expect(activity.actor).to eq follower
      end

      it 'creates Undo activity with the original follow as the entity' do
        expect(activity.entity).to eq following.follow_activity
      end

      it 'is addressed to the target actor' do
        expect(activity.to).to eq [target.federated_url]
      end

      it 'does not cc anyone' do
        expect(activity.cc).to be_nil
      end

      it 'queues NotifyInboxJob' do
        expect(NotifyInboxJob).to have_been_enqueued.with(activity)
      end
    end

    context 'when unfollowing a distant actor' do
      let(:follower) { FactoryBot.create :local_actor }
      let(:target) { FactoryBot.create :distant_actor }
      let(:following) { described_class.create! actor: follower, target_actor: target }
      let!(:activity) do
        following.destroy!
        Activity.find_by(action: 'Undo')
      end

      it 'creates Undo activity when Following is destroyed' do
        expect(activity.action).to eq 'Undo'
      end

      it 'queues NotifyInboxJob' do
        expect(NotifyInboxJob).to have_been_enqueued.with(activity)
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

    context 'when a follow request is accepted' do
      let(:follower) { FactoryBot.create :distant_actor }
      let(:target) { FactoryBot.create :local_actor }
      let(:following) { described_class.create! actor: follower, target_actor: target }
      let!(:original_follow) do
        # Create the original Follow activity that would come from the remote server
        Federails::Activity.create! actor: follower, action: 'Follow', entity: target, to: [target.federated_url]
      end
      let!(:activity) do
        following.accept!(follow_activity: original_follow)
        Activity.find_by(action: 'Accept')
      end

      it 'creates activity with Accept action' do
        expect(activity.action).to eq 'Accept'
      end

      it 'creates Accept activity with the target as the actor' do
        expect(activity.actor).to eq target
      end

      it 'creates Accept activity with the original Follow activity as the entity' do
        expect(activity.entity).to eq original_follow
      end

      it 'is addressed to the follower' do
        expect(activity.to).to eq [follower.federated_url]
      end

      it 'does not cc anyone' do
        expect(activity.cc).to be_nil
      end

      it 'queues NotifyInboxJob' do
        expect(NotifyInboxJob).to have_been_enqueued.with(activity)
      end

      it 'raises when follow_activity is omitted' do
        expect { following.accept! }.to raise_error(ArgumentError)
      end

      it 'raises when follow_activity is explicitly nil' do
        expect { following.accept!(follow_activity: nil) }.to raise_error(ArgumentError)
      end
    end
  end
end
