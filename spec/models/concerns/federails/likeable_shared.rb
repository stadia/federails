RSpec.shared_examples 'Likeable' do |klass, attributes|
  let(:user) { FactoryBot.create :user }
  let!(:instance) do
    if klass.try(:include?, Federails::DataEntity)
      klass.create! attributes.merge(user_id: user.id)
    else
      FactoryBot.create(klass)
    end
  end

  describe 'like' do
    context 'with a different actor' do
      let(:actor) { FactoryBot.create :local_actor }

      it 'creates an activity' do
        expect { instance.like! actor: actor }.to change(Federails::Activity.where(action: 'Like'), :count).by 1
      end

      it 'uses the specified actor' do
        activity = instance.like! actor: actor
        expect(activity.actor).to eq actor
      end

      it 'sends to public collection' do
        activity = instance.like! actor: actor
        expect(activity.to).to eq [Fediverse::Collection::PUBLIC]
      end

      it 'ccs to actors follower collection' do
        activity = instance.like! actor: actor
        expect(activity.cc).to include(actor.followers_url)
        expect(activity.cc).to include(instance.followers_url) if instance.respond_to?(:followers_url)
      end
    end

    if klass.try(:include?, Federails::DataEntity)
      context 'when the entity has no publishable federation URL' do
        let(:actor) { FactoryBot.create :local_actor }

        before do
          allow(instance).to receive(:federated_url).and_return(nil)
        end

        it 'does not create an outbound Like activity' do
          expect { instance.like! actor: actor }
            .not_to change(Federails::Activity.where(action: 'Like'), :count)
        end
      end

      context 'when the entity originated from the Fediverse' do
        let(:actor) { FactoryBot.create :local_actor }
        let(:remote_actor) { FactoryBot.create :distant_actor }
        let!(:remote_instance) do
          klass.create! attributes.merge(
            federails_actor: remote_actor,
            federated_url:   "https://remote.example/notes/#{SecureRandom.uuid}"
          )
        end

        it 'still creates an outbound Like activity targeting the remote entity' do
          expect { remote_instance.like! actor: actor }
            .to change(Federails::Activity.where(action: 'Like'), :count).by 1
        end

        it 'does not create an activity when the liking actor is not local' do
          expect { remote_instance.like! actor: remote_actor }
            .not_to change(Federails::Activity.where(action: 'Like'), :count)
        end
      end
    end
  end

  describe 'dislike' do
    context 'with a different actor' do
      let(:actor) { FactoryBot.create :local_actor }

      it 'creates an activity' do
        expect { instance.dislike! actor: actor }.to change(Federails::Activity.where(action: 'Dislike'), :count).by 1
      end

      it 'uses the specified actor' do
        activity = instance.dislike! actor: actor
        expect(activity.actor).to eq actor
      end

      it 'sends to public collection' do
        activity = instance.dislike! actor: actor
        expect(activity.to).to eq [Fediverse::Collection::PUBLIC]
      end

      it 'ccs to actors follower collection' do
        activity = instance.dislike! actor: actor
        expect(activity.cc).to include(actor.followers_url)
        expect(activity.cc).to include(instance.followers_url) if instance.respond_to?(:followers_url)
      end
    end
  end
end
