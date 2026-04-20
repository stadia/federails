require 'rails_helper'
require 'fediverse/inbox'
require 'fediverse/inbox/follow_handler'
require 'fediverse/request'

module Fediverse
  # rubocop:disable Metrics/ClassLength
  class Inbox
    RSpec.describe FollowHandler do
      let(:local_actor) { FactoryBot.create(:user).federails_actor }
      let(:distant_actor) { FactoryBot.create :distant_actor }

      describe '#handle_create_follow_request' do
        let(:distant_following) do
          {
            'id'     => 'http://example.com/fake_following_request',
            'actor'  => local_actor.federated_url,
            'object' => distant_actor.federated_url,
          }
        end

        it 'creates the following' do
          expect do
            described_class.handle_create_follow_request(distant_following)
          end.to change(Federails::Following, :count).by(1)
        end

        it 'treats duplicate follow requests as idempotent' do
          described_class.handle_create_follow_request(distant_following)

          expect do
            described_class.handle_create_follow_request(distant_following)
          end.not_to change(Federails::Following, :count)
        end

        context 'when the Following is already accepted and a new activity id arrives' do
          let(:inbound_follow) do
            {
              'id'     => 'https://remote.example/follows/original',
              'actor'  => distant_actor.federated_url,
              'object' => local_actor.federated_url,
            }
          end
          let(:duplicate_follow) do
            {
              'id'     => 'https://remote.example/follows/retry',
              'actor'  => distant_actor.federated_url,
              'object' => local_actor.federated_url,
            }
          end

          before do
            described_class.handle_create_follow_request(inbound_follow)
            Federails::Following.find_by!(actor: distant_actor, target_actor: local_actor).update!(status: :accepted)
          end

          it 'creates a new Accept activity referencing the existing Follow activity' do
            expect do
              described_class.handle_create_follow_request(duplicate_follow)
            end.to change(Federails::Activity.where(action: 'Accept'), :count).by(1)

            follow_activity = Federails::Activity.find_by!(actor: distant_actor, action: 'Follow', entity: local_actor)
            accept_activity = Federails::Activity.where(action: 'Accept').order(:created_at).last
            expect(accept_activity.entity).to eq(follow_activity)
            expect(accept_activity.actor).to eq(local_actor)
            expect(accept_activity.to).to eq([distant_actor.federated_url])
          end

          it 'does not create a duplicate Following' do
            expect do
              described_class.handle_create_follow_request(duplicate_follow)
            end.not_to change(Federails::Following, :count)
          end
        end

        context 'when a duplicate Follow arrives for a still-pending Following' do
          let(:inbound_follow) do
            {
              'id'     => 'https://remote.example/follows/pending-original',
              'actor'  => distant_actor.federated_url,
              'object' => local_actor.federated_url,
            }
          end
          let(:duplicate_follow) do
            {
              'id'     => 'https://remote.example/follows/pending-retry',
              'actor'  => distant_actor.federated_url,
              'object' => local_actor.federated_url,
            }
          end

          before do
            described_class.handle_create_follow_request(inbound_follow)
          end

          it 'does not send an Accept' do
            expect do
              described_class.handle_create_follow_request(duplicate_follow)
            end.not_to change(Federails::Activity.where(action: 'Accept'), :count)
          end
        end

        it 'creates a Follow activity before callbacks can accept the follow' do
          inbound_follow = {
            'id'     => 'https://remote.example/follows/1',
            'actor'  => distant_actor.federated_url,
            'object' => local_actor.federated_url,
          }

          expect do
            described_class.handle_create_follow_request(inbound_follow)
          end.to change(Federails::Activity.where(action: 'Follow'), :count).by(1)

          follow_activity = Federails::Activity.find_by!(
            actor:  distant_actor,
            action: 'Follow',
            entity: local_actor
          )
          expect(follow_activity.to).to eq([local_actor.federated_url])
        end
      end

      describe '.dispatch_request for inbound Follow with eager acceptance' do
        let(:remote_actor) { FactoryBot.create :distant_actor }
        let(:payload) do
          {
            'id'     => 'https://remote.example/activities/follow-1',
            'type'   => 'Follow',
            'actor'  => remote_actor.federated_url,
            'object' => local_actor.federated_url,
            'to'     => [local_actor.federated_url],
          }
        end

        before do
          allow(Fediverse::Request).to receive(:dereference) do |value|
            case value
            when payload['object']
              { 'id' => local_actor.federated_url, 'type' => 'Person' }
            when payload['actor']
              { 'id' => remote_actor.federated_url, 'type' => 'Person' }
            else
              value
            end
          end
        end

        around do |example|
          original_accept_follow = User.instance_method(:accept_follow)
          User.send(:define_method, :accept_follow) do |follow, follow_activity:|
            follow.accept!(follow_activity: follow_activity)
          end
          example.run
        ensure
          begin
            User.send(:define_method, :accept_follow, original_accept_follow)
          rescue StandardError => e
            Federails.logger.error { "Failed to restore User#accept_follow in spec: #{e.message}" }
            raise
          end
        end

        it 'records the inbound Follow before accept! tries to reference it' do
          expect { Fediverse::Inbox.dispatch_request(payload) }.not_to raise_error

          follow_activity = Federails::Activity.find_by!(
            actor:         remote_actor,
            action:        'Follow',
            entity:        local_actor,
            federated_url: payload['id']
          )
          accept_activity = Federails::Activity.find_by!(action: 'Accept', actor: local_actor)

          expect(accept_activity.entity).to eq(follow_activity)
          expect(accept_activity.to).to eq([remote_actor.federated_url])
        end

        it 'does not enqueue delivery jobs for the remote Follow activity' do
          expect { Fediverse::Inbox.dispatch_request(payload) }.to have_enqueued_job(Federails::NotifyInboxJob).exactly(1).times
        end
      end

      describe '.dispatch_followed_callback compatibility' do
        let(:follow) { Federails::Following.create!(actor: distant_actor, target_actor: local_actor) }
        let(:follow_activity) do
          Federails::Activity.create!(
            actor:         distant_actor,
            action:        'Follow',
            entity:        local_actor,
            federated_url: 'https://remote.example/activities/follow-compat',
            to:            [local_actor.federated_url]
          )
        end

        it 'passes follow_activity to keyword-capable callbacks' do
          modern_host_class = Class.new do
            extend Federails::ActorEntity::ClassMethods

            after_followed :accept_follow

            def accept_follow(follow, follow_activity:)
              [follow, follow_activity]
            end
          end

          instance = modern_host_class.new
          result = modern_host_class.send(:dispatch_followed_callback, instance, follow, follow_activity: follow_activity)
          expect(result).to eq([follow, follow_activity])
        end

        it 'falls back to the legacy one-argument callback shape' do
          legacy_host_class = Class.new do
            extend Federails::ActorEntity::ClassMethods

            after_followed :accept_follow

            def accept_follow(follow)
              follow
            end
          end

          instance = legacy_host_class.new
          result = legacy_host_class.send(:dispatch_followed_callback, instance, follow, follow_activity: follow_activity)
          expect(result).to eq(follow)
        end

        it 'returns without raising when after_followed is not configured' do
          host_class = Class.new do
            extend Federails::ActorEntity::ClassMethods
          end

          expect do
            host_class.send(:dispatch_followed_callback, host_class.new, follow, follow_activity: follow_activity)
          end.not_to raise_error
        end

        it 'raises NoMethodError when the configured callback is not defined on the instance' do
          host_class = Class.new do
            extend Federails::ActorEntity::ClassMethods

            after_followed :missing_callback
          end

          expect do
            host_class.send(:dispatch_followed_callback, host_class.new, follow, follow_activity: follow_activity)
          end.to raise_error(NoMethodError, /missing_callback/)
        end
      end

      describe '#handle_accept_follow_request' do
        let(:local_following) { Federails::Following.create(actor: local_actor, target_actor: distant_actor) }
        let(:payload) do
          {
            'actor' => distant_actor.federated_url,
          }
        end
        let(:following) do
          {
            'type'   => 'Follow',
            'actor'  => local_following.actor.federated_url,
            'object' => local_following.target_actor.federated_url,
          }
        end

        it 'accepts the following request' do
          allow(Fediverse::Request).to receive(:dereference).and_return(following)
          described_class.handle_accept_follow_request(payload)

          local_following.reload
          expect(local_following).to be_accepted
        end

        it 'returns without raising when no matching following exists' do
          non_existent_payload = {
            'actor'  => distant_actor.federated_url,
            'object' => 'https://remote.example/activities/non-existent-follow',
          }
          following_data = {
            'type'   => 'Follow',
            'actor'  => local_actor.federated_url,
            'object' => distant_actor.federated_url,
          }
          allow(Fediverse::Request).to receive(:dereference).and_return(following_data)

          expect { described_class.handle_accept_follow_request(non_existent_payload) }.not_to raise_error
        end

        it 'returns without raising when the original follow activity cannot be dereferenced' do
          allow(Fediverse::Request).to receive(:dereference).and_return(nil)

          expect { described_class.handle_accept_follow_request(payload.merge('object' => 'https://remote.example/missing')) }.not_to raise_error
        end
      end

      describe '#handle_undo_follow_request' do
        let(:payload) do
          {
            'object' => following,
          }
        end
        let(:following) do
          {
            'type'   => 'Follow',
            'actor'  => local_following.actor.federated_url,
            'object' => local_following.target_actor.federated_url,
          }
        end

        before do
          allow(Fediverse::Request).to receive(:get).and_return(following)
        end

        context 'with a pending following' do
          let(:local_following) { Federails::Following.create(actor: local_actor, target_actor: distant_actor) }

          it 'destroys the target Following' do
            expect do
              described_class.handle_undo_follow_request(payload)
            end.to change(Federails::Following, :count).by(-1)
          end
        end

        context 'with an accepted following' do
          let(:local_following) { Federails::Following.create(actor: local_actor, target_actor: distant_actor, status: :accepted) }

          it 'destroys the target Following' do
            expect do
              described_class.handle_undo_follow_request(payload)
            end.to change(Federails::Following, :count).by(-1)
          end
        end

        context 'when object is a follow URL string' do
          let(:payload) do
            {
              'object' => 'https://remote.example/activities/follow-undo',
            }
          end
          let(:local_following) { Federails::Following.create(actor: local_actor, target_actor: distant_actor) }

          before do
            allow(Fediverse::Request).to receive(:dereference).with(payload['object']).and_return(following)
          end

          it 'dereferences the original activity before destroying the following' do
            expect do
              described_class.handle_undo_follow_request(payload)
            end.to change(Federails::Following, :count).by(-1)
          end
        end
      end

      describe '#handle_reject_follow_request' do
        let!(:pending_following) { Federails::Following.create(actor: local_actor, target_actor: distant_actor) }
        let(:payload) do
          {
            'actor'  => distant_actor.federated_url,
            'object' => 'https://example.com/follows/1',
          }
        end
        let(:follow_object) do
          {
            'type'   => 'Follow',
            'actor'  => pending_following.actor.federated_url,
            'object' => pending_following.target_actor.federated_url,
          }
        end

        before do
          allow(Fediverse::Request).to receive(:dereference).with(payload['object']).and_return(follow_object)
        end

        it 'destroys the pending following' do
          expect do
            described_class.handle_reject_follow_request(payload)
          end.to change(Federails::Following, :count).by(-1)
        end

        it 'does not raise when no matching following exists' do
          pending_following.destroy

          expect do
            described_class.handle_reject_follow_request(payload)
          end.not_to raise_error
        end

        it 'returns without raising when the original follow activity cannot be dereferenced' do
          allow(Fediverse::Request).to receive(:dereference).with(payload['object']).and_return(nil)

          expect { described_class.handle_reject_follow_request(payload) }.not_to raise_error
        end

        it 'does not destroy an accepted following' do
          pending_following.update!(status: :accepted)

          expect do
            described_class.handle_reject_follow_request(payload)
          end.not_to change(Federails::Following, :count)

          expect(pending_following.reload).to be_accepted
        end

        context 'when the activity actor is not the target of the follow' do
          let(:other_actor) { FactoryBot.create :distant_actor }
          let(:payload) do
            {
              'actor'  => other_actor.federated_url,
              'object' => 'https://example.com/follows/1',
            }
          end

          it 'raises an error' do
            expect do
              described_class.handle_reject_follow_request(payload)
            end.to raise_error('Follow not rejected by target actor but by someone else')
          end
        end
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
