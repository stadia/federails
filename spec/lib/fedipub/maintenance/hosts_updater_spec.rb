require 'rails_helper'
require 'fedipub/maintenance/hosts_updater'

RSpec.describe Fedipub::Maintenance::HostsUpdater do
  describe '.run' do
    it 'updates each unique known domain using the configured cache interval' do
      distinct_relation = instance_double(ActiveRecord::Relation)

      allow(Fedipub::Configuration).to receive(:remote_entities_cache_duration).and_return(12.hours)
      allow(Fedipub::Actor).to receive(:distant).and_return(distinct_relation)
      allow(distinct_relation).to receive(:distinct).with(:server).and_return(distinct_relation)
      allow(distinct_relation).to receive(:pluck).with(:server).and_return(['remote.example', 'shared.example'])
      allow(Fedipub::Host).to receive(:pluck).with(:domain).and_return(['shared.example', 'host.example'])
      allow(Fedipub::Host).to receive(:create_or_update)

      described_class.run

      aggregate_failures do
        expect(Fedipub::Host).to have_received(:create_or_update).with('remote.example', min_update_interval: 12.hours).once
        expect(Fedipub::Host).to have_received(:create_or_update).with('shared.example', min_update_interval: 12.hours).once
        expect(Fedipub::Host).to have_received(:create_or_update).with('host.example', min_update_interval: 12.hours).once
      end
    end

    it 'uses the explicit cache interval when provided' do
      distinct_relation = instance_double(ActiveRecord::Relation)

      allow(Fedipub::Actor).to receive(:distant).and_return(distinct_relation)
      allow(distinct_relation).to receive(:distinct).with(:server).and_return(distinct_relation)
      allow(distinct_relation).to receive(:pluck).with(:server).and_return(['remote.example'])
      allow(Fedipub::Host).to receive(:pluck).with(:domain).and_return([])
      allow(Fedipub::Host).to receive(:create_or_update)

      described_class.run(cache_interval: 30.minutes)

      expect(Fedipub::Host).to have_received(:create_or_update).with('remote.example', min_update_interval: 30.minutes)
    end
  end
end
