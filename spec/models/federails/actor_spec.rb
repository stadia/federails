require 'rails_helper'

module Federails
  RSpec.describe Actor, type: :model do
    let(:distant_actor_attributes) { FactoryBot.build(:distant_actor).attributes }
    let(:distant_url) { 'https://mamot.fr/users/mtancoigne' }
    let(:distant_account) { 'mtancoigne@mamot.fr' }
    let(:existing_distant_actor) { FactoryBot.create :distant_actor, federated_url: distant_url, username: 'mtancoigne', server: 'mamot.fr' }
    let(:existing_local_actor) { FactoryBot.create(:user).reload.federails_actor }
    # Cassette which should not be created by any example. Used to test the absence
    # of outgoing requests
    let(:error_cassette) { 'this_should_not_be_here' }
    let(:error_cassette_file) { File.join(VCR.configuration.cassette_library_dir, "#{error_cassette}.yml") }

    before do
      FileUtils.rm_f error_cassette_file
    end

    context 'when actors without UUIDs exist' do
      before do
        existing_distant_actor.update_columns(uuid: nil) # rubocop:disable Rails/SkipsModelValidations
      end

      it 'creates a UUID on demand' do
        # Check it's generated on demand
        uuid = existing_distant_actor.uuid
        expect(uuid).to be_present
        # Check it was saved
        expect(existing_distant_actor.reload.uuid).to eq uuid
      end
    end

    context 'when creating distant actors' do
      it 'fails to create the same actor twice' do
        described_class.create! distant_actor_attributes
        duplicate = described_class.new(distant_actor_attributes)
        duplicate.validate
        expect(duplicate.errors.details[:federated_url][0][:error]).to eq :taken
      end

      it 'does not set the "local" flag' do
        actor = described_class.create! distant_actor_attributes
        expect(actor).not_to be_local
      end
    end

    context 'when creating local actors' do
      it 'fails to create the same local actor twice' do
        user = FactoryBot.create :user
        duplicate = described_class.new(entity: user)
        duplicate.validate
        expect(duplicate.errors.details[:entity_id][0][:error]).to eq :taken
      end

      it 'sets the "local" flag' do
        user = FactoryBot.create :user
        expect(user.federails_actor).to be_local
      end

      it 'creates a new RSA keypair with public key' do
        user = FactoryBot.create :user
        expect(user.federails_actor.public_key).to include 'BEGIN PUBLIC KEY'
      end

      it 'creates a new RSA keypair with private key' do
        user = FactoryBot.create :user
        expect(user.federails_actor.private_key).to include 'BEGIN RSA PRIVATE KEY'
      end
    end

    describe 'hooks' do
      describe 'on_federails_delete_requested' do
        it 'tombstones the actor' do
          actor = FactoryBot.create :distant_actor
          actor.run_callbacks :on_federails_delete_requested

          expect(actor).to be_tombstoned
        end
      end

      describe 'on_federails_undelete_requested' do
        it 'un-tombstones the actor' do
          actor = FactoryBot.create :distant_actor, tombstoned_at: Time.current
          allow(actor).to receive(:sync!)

          expect(actor).to be_tombstoned

          actor.run_callbacks :on_federails_undelete_requested
          aggregate_failures do
            expect(actor).not_to be_tombstoned
            expect(actor).to have_received(:sync!).once
          end
        end
      end

      describe 'after_create' do
        context 'with a local actor' do
          it 'does not fetch domain information' do
            expect { FactoryBot.create :local_actor }.not_to have_enqueued_job(Federails::FetchNodeinfoJob)
          end
        end

        context 'with a remote actor' do
          it 'fetches the domain information' do
            expect { FactoryBot.create :distant_actor }.to have_enqueued_job(Federails::FetchNodeinfoJob)
          end
        end
      end
    end

    describe '#find_by_account' do
      it 'returns local actors' do
        user = FactoryBot.create :user
        result = described_class.find_by_account("#{user.id}@localhost")
        expect(result).to eq user.federails_actor
      end

      it 'returns distant actors' do
        VCR.use_cassette 'actor/find_by_account_get' do
          result = described_class.find_by_account(distant_account)
          expect(result.username).to eq 'mtancoigne'
        end
      end

      it 'returns persisted distant actors' do
        VCR.use_cassette 'actor/find_by_account_get' do
          existing_distant_actor
          result = described_class.find_by_account(distant_account)
          expect(result.id).to eq existing_distant_actor.id
        end
      end

      it 'stores extra data for distant actors' do
        VCR.use_cassette 'actor/find_by_account_get' do
          result = described_class.find_by_account(distant_account)
          expect(result.extensions['manuallyApprovesFollowers']).to be false
        end
      end

      it 'returns distant actors without making a call' do
        # This should not create new cassettes; if this one is created there is an issue
        VCR.use_cassette 'this_should_not_be_here' do
          existing_distant_actor
          described_class.find_by_account(distant_account)
        end
        # rubocop:disable RSpec/PredicateMatcher
        expect(File.exist?(error_cassette_file)).to be_falsey
        # rubocop:enable RSpec/PredicateMatcher
      end
    end

    describe '#find_or_create_by_account' do
      it 'creates distant actor' do
        VCR.use_cassette 'actor/find_or_create_by_account_get' do
          expect do
            described_class.find_or_create_by_account(distant_account)
          end.to change(described_class, :count).by 1
        end
      end

      it 'does not create existing distant actor' do
        VCR.use_cassette 'actor/find_or_create_by_account_get' do
          existing_distant_actor
          expect do
            described_class.find_by_account(distant_account)
          end.not_to change(described_class, :count)
        end
      end
    end

    describe '#find_by_federation_url' do
      it 'returns local actors' do
        user = FactoryBot.create :user
        result = described_class.find_by_federation_url(user.federails_actor.federated_url)
        expect(result).to eq user.federails_actor
      end

      it 'returns distant actors' do
        VCR.use_cassette 'actor/find_by_federation_url_get' do
          result = described_class.find_by_federation_url(distant_url)
          expect(result.username).to eq 'mtancoigne'
        end
      end

      it 'returns persisted distant actors' do
        VCR.use_cassette 'actor/find_by_federation_url_get' do
          existing_distant_actor
          result = described_class.find_by_federation_url(distant_url)
          expect(result.id).to eq existing_distant_actor.id
        end
      end

      it 'returns distant actors without making a call' do
        # This should not create new cassettes; if this one is created there is an issue
        VCR.use_cassette error_cassette do
          existing_distant_actor
          described_class.find_by_federation_url(distant_url)
        end
        # rubocop:disable RSpec/PredicateMatcher
        expect(File.exist?(error_cassette_file)).to be_falsey
        # rubocop:enable RSpec/PredicateMatcher
      end
    end

    describe '#find_or_create_by_federation_url' do
      it 'creates distant actor' do
        VCR.use_cassette 'actor/find_or_create_by_federation_url_get' do
          expect do
            described_class.find_or_create_by_federation_url(distant_url)
          end.to change(described_class, :count).by 1
        end
      end

      it 'does not create existing distant actor' do
        VCR.use_cassette 'actor/find_or_create_by_federation_url_get' do
          existing_distant_actor
          expect do
            described_class.find_or_create_by_federation_url(distant_url)
          end.not_to change(described_class, :count)
        end
      end

      it 'treats acct URIs as account lookups' do
        actor = existing_distant_actor

        allow(described_class).to receive(:find_by_account).with(actor.acct_uri).and_return(actor)
        allow(Fediverse::Webfinger).to receive(:fetch_actor_url)

        described_class.find_or_create_by_federation_url(actor.acct_uri)

        expect(described_class).to have_received(:find_by_account).with(actor.acct_uri)
        expect(Fediverse::Webfinger).not_to have_received(:fetch_actor_url)
      end
    end

    describe '#find_or_create_by_object' do
      context 'when a String is given' do
        it 'fetches the distant actor' do
          allow(described_class).to receive :find_or_create_by_federation_url
          described_class.find_or_create_by_object distant_url
          expect(described_class).to have_received(:find_or_create_by_federation_url).with(distant_url)
        end
      end

      context 'when a Hash is given' do
        it 'fetches the distant actor' do
          hash = { 'id' => distant_url }
          allow(described_class).to receive :find_or_create_by_federation_url
          described_class.find_or_create_by_object hash
          expect(described_class).to have_received(:find_or_create_by_federation_url).with(distant_url)
        end
      end
    end

    describe '#find_local_by_username' do
      let(:user) { FactoryBot.create :user }

      it 'returns the local actor' do
        # ID is used as username in dummy
        expect(described_class.find_local_by_username(user.id)).to eq user.federails_actor
      end

      it 'returns nil when not found' do
        expect(described_class.find_local_by_username('invalid_username')).to be_nil
      end
    end

    describe '#find_local_by_username!' do
      let(:user) { FactoryBot.create :user }

      it 'returns the local actor' do
        # ID is used as username in dummy
        expect(described_class.find_local_by_username!(user.id)).to eq user.federails_actor
      end

      it 'raises an error' do
        expect { described_class.find_local_by_username! 'invalid_username' }.to raise_error ActiveRecord::RecordNotFound
      end
    end

    describe '.profile_url' do
      context 'with a local entity' do
        context 'without a profile_url_method defined' do
          around do |example|
            old_url_method = Federails.actor_entity(User)[:profile_url_method]
            Federails.actor_entity(User)[:profile_url_method] = nil

            example.run

            Federails.actor_entity(User)[:profile_url_method] = old_url_method
          end

          it "returns the actor's url" do
            expected_url = Federails::Engine.routes.url_helpers.server_actor_url(existing_local_actor)
            expect(existing_local_actor.profile_url).to eq expected_url
          end
        end

        context 'with a profile_url_method defined' do
          it 'returns the value from the defined route helper' do
            expected_url = Rails.application.routes.url_helpers.user_url(existing_local_actor.entity)
            expect(existing_local_actor.profile_url).to eq expected_url
          end
        end

        context 'when entity is tombstoned' do
          before do
            existing_local_actor.tombstone!
            existing_local_actor.update! profile_url: 'https://example.com/the_profile'
          end

          it 'returns the actors profile URL' do
            expect(existing_local_actor.profile_url).to eq 'https://example.com/the_profile'
          end
        end
      end

      context 'with a distant entity' do
        it 'returns the actors profile URL' do
          expect(existing_distant_actor.profile_url).to eq existing_distant_actor.attributes['profile_url']
        end
      end
    end

    describe '.shared_inbox_url' do
      context 'with a local actor' do
        it 'returns the server shared inbox route' do
          expected_url = Federails::Engine.routes.url_helpers.server_shared_inbox_url
          expect(existing_local_actor.shared_inbox_url).to eq expected_url
        end
      end

      context 'with a distant actor' do
        it 'returns the stored shared_inbox_url' do
          existing_distant_actor.update! shared_inbox_url: 'https://mamot.fr/inbox'
          expect(existing_distant_actor.shared_inbox_url).to eq 'https://mamot.fr/inbox'
        end

        it 'returns nil when not set' do
          expect(existing_distant_actor.shared_inbox_url).to be_nil
        end
      end
    end

    describe '.tombstone!' do
      context 'with a distant actor' do
        let(:entity) { described_class.create! distant_actor_attributes }

        it 'does not create an activity' do
          expect { entity.tombstone! }.not_to change(Federails::Activity, :count)
        end

        it 'makes the actor tombstoned' do
          entity.tombstone!

          expect(entity.tombstoned_at).not_to be_nil
        end

        it 'saves the entity' do
          entity.tombstone!

          expect(entity).not_to be_changed
        end
      end

      context 'with a local actor' do
        let(:entity) { FactoryBot.create(:user).federails_actor }

        it 'creates an activity' do
          expect { entity.tombstone! }.to change(Federails::Activity, :count).by 1
        end

        it 'makes the actor tombstoned' do
          entity.tombstone!

          expect(entity.tombstoned_at).not_to be_nil
        end

        it 'saves the entity' do
          entity.tombstone!

          expect(entity).not_to be_changed
        end
      end
    end

    describe '.untombstone!' do
      context 'with a distant actor' do
        let(:entity) { described_class.create! distant_actor_attributes.merge(tombstoned_at: Time.current) }

        before do
          allow(entity).to receive(:sync!).and_return(true)
        end

        it 'does not create an activity' do
          expect { entity.untombstone! }.not_to change(Federails::Activity, :count)
        end

        it 'removes the tombstoned flag' do
          entity.untombstone!

          expect(entity.tombstoned_at).to be_nil
        end

        it 'synchronizes the actor' do
          entity.untombstone!

          expect(entity).to have_received(:sync!).once
        end

        it 'saves the entity' do
          entity.untombstone!

          expect(entity).not_to be_changed
        end
      end

      context 'with a local actor' do
        let(:entity) { FactoryBot.create(:user).federails_actor }

        before do
          entity.tombstone!
        end

        it 'creates an activity' do
          expect { entity.untombstone! }.to change(Federails::Activity, :count).by 1
        end

        it 'removes the tombstoned flag' do
          entity.untombstone!

          expect(entity.tombstoned_at).to be_nil
        end

        it 'saves the entity' do
          entity.untombstone!

          expect(entity).not_to be_changed
        end
      end
    end

    describe '.sync!' do
      context 'with a local actor' do
        let(:local_actor) { FactoryBot.create(:user).reload.federails_actor }

        it 'returns false' do
          expect(local_actor.sync!).to be false
        end
      end

      context 'with a distant actor' do
        before do
          existing_distant_actor.update! username: 'old_username'
        end

        it 'updates the actor' do
          VCR.use_cassette 'actor/find_or_create_by_federation_url_get' do
            expect { existing_distant_actor.sync! }.to change { existing_distant_actor.reload.username }.from('old_username').to('mtancoigne')
          end
        end

        it 'returns true' do
          VCR.use_cassette 'actor/find_or_create_by_federation_url_get' do
            expect(existing_distant_actor.sync!).to be true
          end
        end
      end
    end

    describe '.follows?' do
      let(:actor) { FactoryBot.create :local_actor }

      context 'when current actor follows given actor' do
        before do
          Federails::Following.create! actor: actor, target_actor: existing_distant_actor
        end

        it 'returns the Following' do
          expect(actor.follows?(existing_distant_actor)).to be_a Federails::Following
        end
      end

      context 'when current actor does not follow given actor' do
        it 'returns false' do
          expect(actor.follows?(existing_distant_actor)).to be false
        end
      end
    end

    describe '.followed_by?' do
      let(:actor) { FactoryBot.create :local_actor }

      context 'when given actor follows current actor' do
        before do
          Federails::Following.create! actor: existing_distant_actor, target_actor: actor
        end

        it 'returns the Following' do
          expect(actor.followed_by?(existing_distant_actor)).to be_a Federails::Following
        end
      end

      context 'when given actor does not follow current actor' do
        it 'returns false' do
          expect(actor.followed_by?(existing_distant_actor)).to be false
        end
      end
    end

    describe 'local actor' do
      it 'must have a related entity' do
        entity = described_class.new local: true
        entity.validate
        expect(entity.errors[:entity]).to include "can't be blank"
      end
    end

    describe 'distant actor' do
      it 'can be without a related entity' do
        entity = described_class.new local: false
        entity.validate
        expect(entity.errors[:entity]).to be_empty
      end

      it 'can have a related entity' do
        post = FactoryBot.create :post # This makes no sense beside validating the example
        entity = described_class.new local: false, entity: post
        entity.validate
        expect(entity.errors[:entity]).to be_empty
      end
    end

    describe 'accepted relationships' do
      let(:actor) { FactoryBot.create :local_actor }
      let(:follower1) { FactoryBot.create :local_actor }
      let(:follower2) { FactoryBot.create :local_actor }
      let(:following1) { FactoryBot.create :local_actor }
      let(:following2) { FactoryBot.create :local_actor }
      let(:pending_follower) { FactoryBot.create :local_actor }
      let(:pending_following) { FactoryBot.create :local_actor }

      before do
        # Create accepted followers
        accepted_following1 = Federails::Following.create! actor: follower1, target_actor: actor
        accepted_following1.accept!
        accepted_following2 = Federails::Following.create! actor: follower2, target_actor: actor
        accepted_following2.accept!

        # Create pending followers
        Federails::Following.create! actor: pending_follower, target_actor: actor

        # Create accepted followings
        accepted_following3 = Federails::Following.create! actor: actor, target_actor: following1
        accepted_following3.accept!
        accepted_following4 = Federails::Following.create! actor: actor, target_actor: following2
        accepted_following4.accept!

        # Create pending followings
        Federails::Following.create! actor: actor, target_actor: pending_following
      end

      describe '#accepted_followers' do
        it 'returns only accepted followers' do
          expect(actor.accepted_followers.count).to eq 2
          expect(actor.accepted_followers).to contain_exactly(follower1, follower2)
        end

        it 'excludes pending followers' do
          expect(actor.accepted_followers.pluck(:id)).not_to include(
            Federails::Following.where(target_actor: actor, status: :pending).first.actor_id
          )
        end
      end

      describe '#accepted_follows' do
        it 'returns only accepted followings' do
          expect(actor.accepted_follows.count).to eq 2
          expect(actor.accepted_follows).to contain_exactly(following1, following2)
        end

        it 'excludes pending followings' do
          expect(actor.accepted_follows.pluck(:id)).not_to include(
            Federails::Following.where(actor: actor, status: :pending).first.target_actor_id
          )
        end
      end

      describe '#followers' do
        it 'returns all followers including pending' do
          expect(actor.followers.count).to eq 3
        end
      end

      describe '#follows' do
        it 'returns all followings including pending' do
          expect(actor.follows.count).to eq 3
        end
      end
    end
  end
end
