RSpec.shared_examples 'Announceable'
  let(:user) { FactoryBot.create :user }
  let!(:instance) { Fixtures::Classes::FakeDataModel.create! FactoryBot.attributes_for(:post, user_id: user.id) }

  context 'with default values (self-announce)' do
    it 'creates an activity' do
      expect { instance.announce! }.to change(Federails::Activity.where(action: 'Announce'), :count).by 1
    end

    it 'assigns self as actor' do
      activity = instance.announce!
      expect(activity.actor).to eq instance.federails_actor
    end

    it 'sends to public collection' do
      activity = instance.announce!
      expect(activity.to).to eq [Fediverse::Collection::PUBLIC]
    end

    it 'ccs to actors follower collection' do
      activity = instance.announce!
      expect(activity.cc).to eq [instance.federails_actor.followers_url]
    end
  end

  context 'with a different actor' do
    let(:another_user) { FactoryBot.create :user }
    let(:actor) { another_user.federails_actor }

    it 'uses the specified actor' do
      activity = instance.announce! actor: actor
      expect(activity.actor).to eq actor
    end

    it 'sends to public collection' do
      activity = instance.announce! actor: actor
      expect(activity.to).to eq [Fediverse::Collection::PUBLIC]
    end

    it 'ccs to actors follower collection' do
      activity = instance.announce! actor: actor
      expect(activity.cc).to eq [actor.followers_url]
    end
  end
end
