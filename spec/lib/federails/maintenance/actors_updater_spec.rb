require 'rails_helper'
require 'federails/maintenance/actors_updater'

RSpec.describe Federails::Maintenance::ActorsUpdater do
  let(:actor_url) { 'https://mamot.fr/users/mtancoigne' }
  let!(:distant_actor) do
    actor = nil
    VCR.use_cassette 'actor/find_by_federation_url_get' do
      actor = Fediverse::Webfinger.fetch_actor_url(actor_url)
      ActiveRecord::RecordNotFound
    end
    actor.save!
    actor
  end

  describe '.run' do
    let(:updated_actor_response) do
      entity = distant_actor.dup
      entity.assign_attributes(username: 'bob')
      entity
    end

    before do
      allow(Fediverse::Webfinger).to receive(:fetch_actor_url).with(actor_url).and_return updated_actor_response
    end

    it 'updates the actor' do
      described_class.run distant_actor
      distant_actor.reload

      expect(distant_actor.username).to eq 'bob'
    end

    it 'handles a block' do
      proc = ->(actor, status) { raise "#{actor.federated_url}:#{status}" }

      expect { described_class.run(distant_actor, &proc) }.to raise_error "#{distant_actor.federated_url}:updated"
    end

    it 'returns ignored_local for local actors' do
      local_actor = FactoryBot.create :local_actor
      result = nil

      described_class.run(local_actor) { |_actor, status| result = status }

      expect(result).to eq(:ignored_local)
    end

    it 'returns not_found when sync raises ActiveRecord::RecordNotFound' do
      allow(distant_actor).to receive(:sync!).and_raise(ActiveRecord::RecordNotFound)
      result = nil

      described_class.run(distant_actor) { |_actor, status| result = status }

      expect(result).to eq(:not_found)
    end

    it 'returns failed when sync raises an unexpected error' do
      allow(distant_actor).to receive(:sync!).and_raise(StandardError)
      result = nil

      described_class.run(distant_actor) { |_actor, status| result = status }

      expect(result).to eq(:failed)
    end
  end

  describe 'private #actors_list' do
    it 'handles various values as parameter' do
      aggregate_failures do
        expect(described_class.send(:actors_list, distant_actor.id)).to eq [distant_actor]
        expect(described_class.send(:actors_list, distant_actor.federated_url)).to eq [distant_actor]
        expect(described_class.send(:actors_list, [distant_actor.federated_url])).to eq [distant_actor]
        expect(described_class.send(:actors_list, [distant_actor])).to eq [distant_actor]
        expect(described_class.send(:actors_list, Federails::Actor.distant)).to eq [distant_actor]
      end
    end

    it 'returns all distant actors when parameter is nil' do
      expect(described_class.send(:actors_list, nil)).to include(distant_actor)
    end

    it 'raises for unsupported parameter types' do
      expect do
        described_class.send(:actors_list, :invalid)
      end.to raise_error(/Cannot extract actors/)
    end
  end
end
