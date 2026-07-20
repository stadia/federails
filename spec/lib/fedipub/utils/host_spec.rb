require 'rails_helper'
require 'federails/utils/host'

RSpec.describe Federails::Utils::Host do
  describe '#localhost' do
    # Backup Rails configuration
    before do
      @old_site_host = Federails.configuration.site_host
      @old_site_port = Federails.configuration.site_port
    end

    # Restore Rails configuration
    after do
      Federails.configuration.site_host = @old_site_host # rubocop:disable RSpec/InstanceVariable
      Federails.configuration.site_port = @old_site_port # rubocop:disable RSpec/InstanceVariable
    end

    it 'returns local host and port' do
      Federails.configuration.site_host = 'http://localhost'
      Federails.configuration.site_port = 3000

      expect(described_class.localhost).to eq 'localhost:3000'
    end

    context 'when a common port is declared' do
      it 'returns host only' do
        Federails.configuration.site_host = 'http://example.com'
        Federails.configuration.site_port = 80

        expect(described_class.localhost).to eq 'example.com'
      end
    end

    context 'when no port is declared' do
      it 'returns host only' do
        Federails.configuration.site_host = 'http://example.com'
        Federails.configuration.site_port = nil

        expect(described_class.localhost).to eq 'example.com'
      end
    end
  end

  describe '#local_url?' do
    context 'when URL points to the local server' do
      it 'returns true' do
        expect(described_class.local_url?('http://localhost/something/else')).to be true
      end
    end

    context 'when URL does not point to the local server' do
      it 'returns false' do
        # during tests, localhost has no port
        expect(described_class.local_url?('http://localhost:3000/something/else')).to be false
      end
    end
  end

  describe '#local_route' do
    context 'when URL is a local URL' do
      it 'returns a Rails route' do
        url = 'http://localhost/'
        expect(described_class.local_route(url)).to be_a Hash
      end
    end

    context 'when URL is not a local url' do
      it 'returns nil' do
        url = 'https://google.com'
        expect(described_class.local_route(url)).to be_nil
      end
    end
  end
end
