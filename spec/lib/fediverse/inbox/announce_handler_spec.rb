require 'rails_helper'
require 'fediverse/inbox/announce_handler'

RSpec.describe Fediverse::Inbox::AnnounceHandler do
  describe '.handle_announce' do
    let(:entity) do
      Fixtures::Classes::FakeArticleDataModel.create!(
        user:    FactoryBot.create(:user),
        title:   'A post',
        content: 'body'
      )
    end
    let(:activity) { { 'type' => 'Announce', 'object' => entity.federated_url } }

    it 'dispatches to the data entity hook' do
      allow(Federails::Utils::Object).to receive(:find_or_initialize).with(entity.federated_url).and_return(entity)
      allow(entity).to receive(:run_callbacks).with(:on_federails_announce_received).and_yield

      expect(described_class.handle_announce(activity)).to be true
      expect(entity).to have_received(:run_callbacks).with(:on_federails_announce_received)
    end

    it 'returns true when no target entity is resolved' do
      allow(Federails::Utils::Object).to receive(:find_or_initialize).and_return(nil)
      expect(described_class.handle_announce(activity)).to be true
    end
  end

  describe '.handle_undo_announce' do
    let(:actor_url) { 'https://remote.example/users/alice' }
    let(:entity) do
      Fixtures::Classes::FakeArticleDataModel.create!(
        user:    FactoryBot.create(:user),
        title:   'A post',
        content: 'body'
      )
    end
    let(:activity) do
      {
        'type'   => 'Undo',
        'actor'  => actor_url,
        'object' => { 'type' => 'Announce', 'actor' => actor_url, 'object' => entity.federated_url },
      }
    end

    it 'dispatches to the data entity undo hook' do
      allow(Fediverse::Request).to receive(:dereference).with(activity['object']).and_return(activity['object'])
      allow(Federails::Utils::Object).to receive(:find_or_initialize).with(entity.federated_url).and_return(entity)
      allow(entity).to receive(:run_callbacks).with(:on_federails_undo_announce_received).and_yield

      expect(described_class.handle_undo_announce(activity)).to be true
      expect(entity).to have_received(:run_callbacks).with(:on_federails_undo_announce_received)
    end

    it 'returns true when no target entity is resolved' do
      allow(Fediverse::Request).to receive(:dereference).with(activity['object']).and_return(activity['object'])
      allow(Federails::Utils::Object).to receive(:find_or_initialize).and_return(nil)
      expect(described_class.handle_undo_announce(activity)).to be true
    end

    it 'returns false when undo actor does not match original actor' do
      allow(Fediverse::Request).to receive(:dereference).with(activity['object']).and_return(activity['object'].merge('actor' => 'https://remote.example/users/bob'))

      expect(described_class.handle_undo_announce(activity)).to be false
    end
  end
end
