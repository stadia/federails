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
        expect(activity.cc).to eq [actor.followers_url]
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
        expect(activity.cc).to eq [actor.followers_url]
      end
    end
  end
end
