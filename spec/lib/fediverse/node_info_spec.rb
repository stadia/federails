require 'rails_helper'

require 'fediverse/node_info'

RSpec.describe Fediverse::NodeInfo do
  describe '.fetch' do
    let(:domain) { 'mamot.fr' }
    let(:wk_nodeinfo_url) { "http://#{domain}/.well-known/nodeinfo" }

    context 'when node is a valid activitypub node' do
      it 'returns a Hash' do
        VCR.use_cassette 'fediverse/nodeinfo/get_200' do
          expect(described_class.fetch(domain)).to be_a Hash
        end
      end
    end

    context 'when node does not support activitypub' do
      let(:nodeinfo_url) { 'https://mamot.fr/nodeinfo/2.0' }
      let(:fake_wk_response) do
        { 'links' => [{ 'rel' => 'http://nodeinfo.diaspora.software/ns/schema/2.0', 'href' => nodeinfo_url }] }
      end
      let(:fake_response) do
        {
          'version'           => '2.0',
          'software'          => {
            'name'    => 'mastodon',
            'version' => '4.3.4',
          },
          'protocols'         => ['not_activitypub'],
          'services'          => {
            'outbound' => [],
            'inbound'  => [],
          },
          'usage'             => {},
          'openRegistrations' => true,
          'metadata'          => {
            'nodeName'        => 'Mamot - Le Mastodon de La Quadrature du Net ',
            'nodeDescription' => 'Mamot.fr est un serveur Mastodon francophone, géré par La Quadrature du Net.',
          },
        }
      end

      before do
        allow(Federails::Utils::JsonRequest).to receive(:get_json).with(wk_nodeinfo_url, follow_redirects: true).and_return(fake_wk_response).once
        allow(Federails::Utils::JsonRequest).to receive(:get_json).with(nodeinfo_url).and_return(fake_response).once
      end

      it 'raises an exception' do
        expect { described_class.fetch(domain) }.to raise_error Fediverse::NodeInfo::NoActivityPubError
      end
    end

    context 'when nodeinfo only exposes schema 2.1' do
      let(:nodeinfo_url) { 'https://mamot.fr/nodeinfo/2.1' }
      let(:fake_wk_response) do
        { 'links' => [{ 'rel' => 'http://nodeinfo.diaspora.software/ns/schema/2.1', 'href' => nodeinfo_url }] }
      end
      let(:fake_response) do
        {
          'version'   => '2.1',
          'software'  => { 'name' => 'mastodon', 'version' => '4.3.4' },
          'protocols' => ['activitypub'],
          'services'  => { 'outbound' => [], 'inbound' => [] },
        }
      end

      before do
        allow(Federails::Utils::JsonRequest).to receive(:get_json).with(wk_nodeinfo_url, follow_redirects: true).and_return(fake_wk_response).once
        allow(Federails::Utils::JsonRequest).to receive(:get_json).with(nodeinfo_url).and_return(fake_response).once
      end

      it 'uses schema 2.1 endpoint' do
        expect(described_class.fetch(domain)[:nodeinfo_url]).to eq nodeinfo_url
      end
    end

    context 'when nodeinfo exposes both schema 2.0 and 2.1' do
      let(:nodeinfo_url) { 'https://mamot.fr/nodeinfo/2.1' }
      let(:fake_wk_response) do
        {
          'links' => [
            { 'rel' => 'http://nodeinfo.diaspora.software/ns/schema/2.0', 'href' => 'https://mamot.fr/nodeinfo/2.0' },
            { 'rel' => 'http://nodeinfo.diaspora.software/ns/schema/2.1', 'href' => nodeinfo_url },
          ],
        }
      end
      let(:fake_response) do
        {
          'version'   => '2.1',
          'software'  => { 'name' => 'mastodon', 'version' => '4.3.4' },
          'protocols' => ['activitypub'],
          'services'  => { 'outbound' => [], 'inbound' => [] },
        }
      end

      before do
        allow(Federails::Utils::JsonRequest).to receive(:get_json).with(wk_nodeinfo_url, follow_redirects: true).and_return(fake_wk_response).once
        allow(Federails::Utils::JsonRequest).to receive(:get_json).with(nodeinfo_url).and_return(fake_response).once
      end

      it 'prefers schema 2.1 endpoint' do
        expect(described_class.fetch(domain)[:nodeinfo_url]).to eq nodeinfo_url
      end
    end

    context 'when node has no nodeinfo' do
      before do
        allow(Federails::Utils::JsonRequest).to receive(:get_json).with(wk_nodeinfo_url, follow_redirects: true).and_raise(Federails::Utils::JsonRequest::UnhandledResponseStatus).once
      end

      it 'raises an exception' do
        expect { described_class.fetch(domain) }.to raise_error Federails::Utils::JsonRequest::UnhandledResponseStatus
      end
    end
  end
end
