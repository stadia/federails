require 'rails_helper'
require 'fediverse/inbox/announce_handler'

RSpec.describe Fediverse::Inbox::AnnounceHandler do
  let(:distant_actor) { FactoryBot.create :distant_actor }
  let(:local_actor) { FactoryBot.create(:user).federails_actor }

  describe '.handle_announce' do
    let(:activity) do
      {
        'id'     => 'https://example.com/activities/announce-1',
        'type'   => 'Announce',
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

    it 'creates an activity with action Announce' do
      expect { described_class.handle_announce(activity) }
        .to change(Federails::Activity, :count).by(1)

      announce = Federails::Activity.last
      expect(announce.action).to eq('Announce')
      expect(announce.actor).to eq(distant_actor)
      expect(announce.entity).to eq(local_actor)
      expect(announce.federated_url).to eq('https://example.com/activities/announce-1')
    end

    it 'returns true on success' do
      expect(described_class.handle_announce(activity)).to be true
    end

    it 'returns false when actor cannot be found' do
      allow(Federails::Actor).to receive(:find_or_create_by_federation_url).and_return(nil)
      expect(described_class.handle_announce(activity)).to be false
    end
  end

  describe '.handle_undo_announce' do
    let(:announce_activity) do
      FactoryBot.create :activity, actor: distant_actor, entity: local_actor,
                                   action: 'Announce', federated_url: 'https://example.com/activities/announce-1'
    end

    let(:activity) do
      {
        'id'     => 'https://example.com/activities/undo-announce-1',
        'type'   => 'Undo',
        'actor'  => distant_actor.federated_url,
        'object' => {
          'id'   => 'https://example.com/activities/announce-1',
          'type' => 'Announce',
        },
      }
    end

    before do
      announce_activity
    end

    it 'destroys the announce activity' do
      expect { described_class.handle_undo_announce(activity) }
        .to change(Federails::Activity, :count).by(-1)
    end

    it 'returns true on success' do
      expect(described_class.handle_undo_announce(activity)).to be true
    end

    it 'returns false when announce activity not found' do
      activity['object']['id'] = 'https://example.com/nonexistent'
      expect(described_class.handle_undo_announce(activity)).to be false
    end
  end
end
