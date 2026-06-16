require 'rails_helper'

RSpec.describe Federails::Host do
  describe '#create_or_update' do
    let(:domain) { 'mamot.fr' }

    context 'when host does not exist in database' do
      it 'creates the host' do
        VCR.use_cassette 'fediverse/nodeinfo/get_200' do
          expect { described_class.create_or_update(domain) }.to change(described_class, :count).by 1
        end
      end
    end

    context 'when a competing job inserts the same domain concurrently' do
      it 'returns the host created by the other job instead of raising' do
        VCR.use_cassette 'fediverse/nodeinfo/get_200' do
          competitor = described_class.create! domain: domain

          # A fresh record built before the competitor committed: sync! will hit
          # the domain uniqueness check and lose the race.
          fresh = described_class.new domain: domain
          allow(described_class).to receive(:find_or_initialize_by).with(domain: domain).and_return(fresh)

          result = nil
          expect { result = described_class.create_or_update(domain) }.not_to change(described_class, :count)
          expect(result).to eq competitor
        end
      end
    end

    context 'when sync! fails for an unrelated reason' do
      it 're-raises the error' do
        fresh = described_class.new domain: domain
        allow(described_class).to receive(:find_or_initialize_by).with(domain: domain).and_return(fresh)
        allow(fresh).to receive(:sync!).and_raise(ActiveRecord::RecordInvalid.new(fresh))

        expect { described_class.create_or_update(domain) }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when host already exists' do
      let!(:host) { described_class.create domain: domain }

      around do |example|
        VCR.use_cassette 'fediverse/nodeinfo/get_200' do
          example.run
        end
      end

      it 'does not create a new host' do
        expect { described_class.create_or_update(domain) }.not_to change(described_class, :count)
      end

      it 'updates the host' do
        expect { described_class.create_or_update(domain) }.to change { host.reload.software_name }.from(nil).to 'mastodon'
      end

      context 'with a big interval' do
        it 'does not fetch data' do
          expect { described_class.create_or_update(domain, min_update_interval: 1.day) }.not_to(change { host.reload.software_name })
        end
      end
    end
  end
end
