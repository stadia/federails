RSpec.shared_examples 'Likeable' do
  let(:user) { FactoryBot.create :user }
  let!(:instance) { Fixtures::Classes::FakeDataModel.create! FactoryBot.attributes_for(:post, user_id: user.id) }

  describe 'like' do
    context 'with a different actor' do
      let(:another_user) { FactoryBot.create :user }
      let(:actor) { another_user.federails_actor }

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
        expect(activity.cc).to eq [actor.followers_url]
      end
    end
  end

  describe 'dislike' do
    context 'with a different actor' do
      let(:another_user) { FactoryBot.create :user }
      let(:actor) { another_user.federails_actor }

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
        expect(activity.cc).to eq [actor.followers_url]
      end
    end
  end
end
