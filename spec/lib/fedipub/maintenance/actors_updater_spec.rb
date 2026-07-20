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
  end

  describe 'private #actors_list' do
    it 'handles various values as parameter' do # rubocop:disable RSpec/ExampleLength
      aggregate_failures do
        expect(described_class.send(:actors_list, distant_actor.id)).to eq [distant_actor]
        expect(described_class.send(:actors_list, distant_actor.federated_url)).to eq [distant_actor]
        expect(described_class.send(:actors_list, [distant_actor.federated_url])).to eq [distant_actor]
        expect(described_class.send(:actors_list, [distant_actor])).to eq [distant_actor]
        expect(described_class.send(:actors_list, Federails::Actor.distant)).to eq [distant_actor]
      end
    end
  end
end
