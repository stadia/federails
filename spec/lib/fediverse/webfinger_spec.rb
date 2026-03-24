require 'rails_helper'
require 'fediverse/webfinger'

module Fediverse
  RSpec.describe Webfinger do
    describe '#split_account' do
      context 'with only an username' do
        let(:account) { 'user' }

        it 'extracts username' do
          results = described_class.split_account(account)
          expect(results[:username]).to eq 'user'
        end
      end

      context 'with only a username with leading @' do
        let(:account) { '@user' }

        it 'extracts username' do
          results = described_class.split_account(account)
          expect(results[:username]).to eq 'user'
        end
      end

      context 'with a complete account string' do
        let(:account) { 'user@domain.tld' }

        it 'extracts username' do
          results = described_class.split_account(account)
          expect(results[:username]).to eq 'user'
        end

        it 'extracts domain' do
          results = described_class.split_account(account)
          expect(results[:domain]).to eq 'domain.tld'
        end
      end

      context 'with a complete account string with leading @' do
        let(:account) { '@user@domain.tld' }

        it 'extracts username' do
          results = described_class.split_account(account)
          expect(results[:username]).to eq 'user'
        end

        it 'extracts domain' do
          results = described_class.split_account(account)
          expect(results[:domain]).to eq 'domain.tld'
        end
      end

      context 'with uppercase characters in username' do
        let(:account) { '@ZyryabRoma@mastodon.social' }

        it 'extracts username preserving case' do
          results = described_class.split_account(account)
          expect(results[:username]).to eq 'ZyryabRoma'
        end

        it 'extracts domain' do
          results = described_class.split_account(account)
          expect(results[:domain]).to eq 'mastodon.social'
        end
      end

      context 'with a full acct: URI' do
        let(:resource_string) { 'acct:user@domain.tld' }

        it 'extracts username from the resource string' do
          results = described_class.split_account(resource_string)
          expect(results[:username]).to eq 'user'
        end

        it 'extracts domain from the resource string' do
          results = described_class.split_account(resource_string)
          expect(results[:domain]).to eq 'domain.tld'
        end
      end
    end

    describe '#local_user?' do
      let(:local_domain) { 'domain.tld' }
      let(:local_port) { 80 }

      context 'with only an username' do
        let(:account) { { username: 'user', domain: nil } }

        it 'returns true' do
          result = described_class.local_user?(account)
          expect(result).to be_truthy
        end
      end

      context 'with an username and domain' do
        # Rails don't have a port during tests. Check environments/test.rb for
        # action mailer's default_url configuration

        it 'returns true when domain matches' do
          account = { username: 'user', domain: 'localhost' }
          result = described_class.local_user?(account)
          expect(result).to be_truthy
        end

        it 'returns false when domain mismatches' do
          account = { username: 'user', domain: 'other_host' }
          result = described_class.local_user?(account)
          expect(result).to be_falsey
        end

        it 'returns false when port mismatches' do
          account = { username: 'user', domain: 'localhost:3000' }
          result = described_class.local_user?(account)
          expect(result).to be_falsey
        end
      end
    end

    describe '#webfinger' do
      it 'returns federation id' do
        VCR.use_cassette 'fediverse/webfinger/webfinger_get_200' do
          expect(described_class.webfinger('mtancoigne', 'mamot.fr')).to eq 'https://mamot.fr/users/mtancoigne'
        end
      end

      it "raises an error on 404's" do
        VCR.use_cassette 'fediverse/webfinger/webfinger_get_404' do
          expect do
            described_class.webfinger('some_inexistant_account', 'mamot.fr')
          end.to raise_error ActiveRecord::RecordNotFound
        end
      end

      it 'raises an error when domain don\'t exists' do
        VCR.use_cassette 'fediverse/webfinger/webfinger_get_bad_domain' do
          expect do
            described_class.webfinger('some_inexistant_account', 'some_inexistant_domain.com')
          end.to raise_error ActiveRecord::RecordNotFound
        end
      end

      it 'raises an error on invalid payloads' do
        allow(described_class).to receive(:webfinger_response).and_return(nil)

        expect do
          described_class.webfinger('mtancoigne', 'mamot.fr')
        end.to raise_error ActiveRecord::RecordNotFound
      end

      it 'fetches remote follow URL template' do
        VCR.use_cassette 'fediverse/webfinger/webfinger_get_200' do
          expect(described_class.remote_follow_url('mtancoigne', 'mamot.fr')).to eq 'https://mamot.fr/authorize_interaction?uri={uri}'
        end
      end

      it 'generates a complete remote follow URL if local actor URL is provided' do
        VCR.use_cassette 'fediverse/webfinger/webfinger_get_200' do
          expect(described_class.remote_follow_url('mtancoigne', 'mamot.fr', actor_url: 'https://example.com')).to eq 'https://mamot.fr/authorize_interaction?uri=https%3A%2F%2Fexample.com'
        end
      end

      it 'returns nil when the remote follow template is missing' do
        allow(described_class).to receive(:webfinger_response).and_return({ 'links' => [] })

        expect(described_class.remote_follow_url('mtancoigne', 'mamot.fr')).to be_nil
      end

      it 'raises on invalid payload for remote follow url' do
        allow(described_class).to receive(:webfinger_response).and_return(nil)

        expect do
          described_class.remote_follow_url('mtancoigne', 'mamot.fr')
        end.to raise_error ActiveRecord::RecordNotFound
      end
    end

    describe '#fetch_actor_url' do
      it 'returns an Actor' do
        VCR.use_cassette 'fediverse/webfinger/fetch_actor_url_get' do
          expect(described_class.fetch_actor_url('https://mamot.fr/users/mtancoigne')).to be_a Federails::Actor
        end
      end

      it 'returns a valid actor' do
        VCR.use_cassette 'fediverse/webfinger/fetch_actor_url_get' do
          expect(described_class.fetch_actor_url('https://mamot.fr/users/mtancoigne')).to be_valid
        end
      end

      it 'raises an error when failing' do
        VCR.use_cassette 'fediverse/webfinger/webfinger_get_url_404' do
          allow(described_class).to receive(:signed_get_json).with('https://example.com/users/jdoe').and_raise(ActiveRecord::RecordNotFound)

          expect do
            described_class.fetch_actor_url('https://example.com/users/jdoe')
          end.to raise_error ActiveRecord::RecordNotFound
        end
      end

      it 'raises an error on invalid actor payloads' do
        allow(described_class).to receive(:get_json).and_return(nil)

        expect do
          described_class.fetch_actor_url('https://example.com/users/jdoe')
        end.to raise_error ActiveRecord::RecordNotFound
      end

      it 'uses signed fetch fallback when unsigned fetch fails' do
        signed_payload = {
          'id'                => 'https://example.com/users/jdoe',
          'preferredUsername' => 'jdoe',
          'type'              => 'Person',
          'inbox'             => 'https://example.com/users/jdoe/inbox',
          'outbox'            => 'https://example.com/users/jdoe/outbox',
          'followers'         => 'https://example.com/users/jdoe/followers',
          'following'         => 'https://example.com/users/jdoe/following',
        }
        allow(described_class).to receive(:get_json).and_raise(ActiveRecord::RecordNotFound)
        allow(described_class).to receive(:signed_get_json).with('https://example.com/users/jdoe').and_return(signed_payload)

        actor = described_class.fetch_actor_url('https://example.com/users/jdoe')

        expect(actor.username).to eq('jdoe')
      end
    end

    describe '#fetch_actor' do
      it 'returns an Actor' do
        VCR.use_cassette 'fediverse/webfinger/fetch_actor_get' do
          expect(described_class.fetch_actor('mtancoigne', 'mamot.fr')).to be_a Federails::Actor
        end
      end

      it 'saves public key' do
        VCR.use_cassette 'fediverse/webfinger/fetch_actor_url_get' do
          actor = described_class.fetch_actor_url('https://mamot.fr/users/mtancoigne')
          expect(actor.public_key).to include 'BEGIN PUBLIC KEY'
        end
      end

      it 'raises an error when failing' do
        VCR.use_cassette 'fediverse/webfinger/webfinger_get_404' do
          expect do
            described_class.fetch_actor('some_inexistant_account', 'mamot.fr')
          end.to raise_error ActiveRecord::RecordNotFound
        end
      end
    end

    describe 'private helpers' do
      describe '.server_and_port' do
        it 'omits the default https port' do
          expect(described_class.send(:server_and_port, 'https://example.com:443/users/alice')).to eq('example.com')
        end

        it 'keeps non-default ports' do
          expect(described_class.send(:server_and_port, 'https://example.com:8443/users/alice')).to eq('example.com:8443')
        end
      end

      describe '.signed_get_json' do
        let(:local_actor) { FactoryBot.create(:local_actor) }

        it 'raises when no local actor is available' do
          allow(Federails::Actor).to receive_message_chain(:where, :where, :not, :first).and_return(nil)

          expect do
            described_class.send(:signed_get_json, 'https://example.com/users/jdoe')
          end.to raise_error ActiveRecord::RecordNotFound
        end

        it 'raises when signed get returns an unhandled status' do
          allow(Federails::Actor).to receive_message_chain(:where, :where, :not, :first).and_return(local_actor)
          allow(Fediverse::Signature).to receive(:signed_get).and_raise(Federails::Utils::JsonRequest::UnhandledResponseStatus.new('404'))

          expect do
            described_class.send(:signed_get_json, 'https://example.com/users/jdoe')
          end.to raise_error ActiveRecord::RecordNotFound
        end

        it 'raises when signed get cannot connect' do
          allow(Federails::Actor).to receive_message_chain(:where, :where, :not, :first).and_return(local_actor)
          allow(Fediverse::Signature).to receive(:signed_get).and_raise(Faraday::ConnectionFailed.new('boom'))

          expect do
            described_class.send(:signed_get_json, 'https://example.com/users/jdoe')
          end.to raise_error ActiveRecord::RecordNotFound
        end

        it 'raises when signed get returns invalid json' do
          allow(Federails::Actor).to receive_message_chain(:where, :where, :not, :first).and_return(local_actor)
          allow(Fediverse::Signature).to receive(:signed_get).and_raise(JSON::ParserError)

          expect do
            described_class.send(:signed_get_json, 'https://example.com/users/jdoe')
          end.to raise_error ActiveRecord::RecordNotFound
        end
      end
    end
  end
end
