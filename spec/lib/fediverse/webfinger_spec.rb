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
    end

    describe '#split_resource_account' do
      let(:resource_string) { 'acct:user@domain.tld' }

      it 'extracts username from the resource string' do
        results = described_class.split_resource_account(resource_string)
        expect(results[:username]).to eq 'user'
      end

      it 'extracts domain from the resource string' do
        results = described_class.split_resource_account(resource_string)
        expect(results[:domain]).to eq 'domain.tld'
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
          expect do
            described_class.fetch_actor_url('https://example.com/users/jdoe')
          end.to raise_error ActiveRecord::RecordNotFound
        end
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
  end
end
