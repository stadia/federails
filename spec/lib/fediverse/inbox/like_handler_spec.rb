require 'rails_helper'
require 'fediverse/inbox/like_handler'

RSpec.describe Fediverse::Inbox::LikeHandler do
  let(:distant_actor) { FactoryBot.create :distant_actor }
  let(:local_actor) { FactoryBot.create(:user).federails_actor }

  describe '.handle_like' do
    let(:activity) do
      {
        'id'     => 'https://example.com/activities/like-1',
        'type'   => 'Like',
        'actor'  => distant_actor.federated_url,
        'object' => local_actor.federated_url,
      }
    end

    before do
      allow(Federails::Actor).to receive(:find_or_create_by_federation_url)
        .with(distant_actor.federated_url).and_return(distant_actor)
      allow(Federails::Utils::Object).to receive(:find_or_initialize)
        .with(local_actor.federated_url).and_return(local_actor)
    end

    it 'creates an activity with action Like' do
      expect { described_class.handle_like(activity) }
        .to change(Federails::Activity, :count).by(1)

      like = Federails::Activity.last
      expect(like.action).to eq('Like')
      expect(like.actor).to eq(distant_actor)
      expect(like.entity).to eq(local_actor)
      expect(like.federated_url).to eq('https://example.com/activities/like-1')
    end

    it 'returns true on success' do
      expect(described_class.handle_like(activity)).to be true
    end

    it 'returns false when actor cannot be found' do
      allow(Federails::Actor).to receive(:find_or_create_by_federation_url).and_return(nil)
      expect(described_class.handle_like(activity)).to be false
    end
  end

  describe '.handle_undo_like' do
    let(:like_activity) do
      FactoryBot.create :activity, actor: distant_actor, entity: local_actor,
                                   action: 'Like', federated_url: 'https://example.com/activities/like-1'
    end

    let(:activity) do
      {
        'id'     => 'https://example.com/activities/undo-like-1',
        'type'   => 'Undo',
        'actor'  => distant_actor.federated_url,
        'object' => {
          'id'   => 'https://example.com/activities/like-1',
          'type' => 'Like',
        },
      }
    end

    before do
      like_activity
    end

    it 'destroys the like activity' do
      expect { described_class.handle_undo_like(activity) }
        .to change(Federails::Activity, :count).by(-1)
    end

    it 'returns true on success' do
      expect(described_class.handle_undo_like(activity)).to be true
    end

    it 'returns false when like activity not found' do
      activity['object']['id'] = 'https://example.com/nonexistent'
      expect(described_class.handle_undo_like(activity)).to be false
    end
  end
end
