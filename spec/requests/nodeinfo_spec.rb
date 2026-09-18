require 'rails_helper'

RSpec.describe '/nodeinfo', type: :request do
  describe 'GET /.well-known/nodeinfo' do
    it 'renders a successful response' do
      get fedipub.node_info_url
      expect(response).to be_successful
    end

    it 'includes a link to the nodeinfo details' do
      get fedipub.node_info_url
      link = response.parsed_body['links'].find { |link| link['rel'] == 'http://nodeinfo.diaspora.software/ns/schema/2.0' }
      expect(link['href']).to match(%r{http://localhost:3000/nodeinfo/2.0})
    end

    it 'includes a FEP-2677 link to the application actor' do
      get fedipub.node_info_url
      link = response.parsed_body['links'].find { |link| link['rel'] == 'https://www.w3.org/ns/activitystreams#Application' }
      expect(link['href']).to match(%r{http://localhost/federation/actors/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}})
    end

    it 'rejects badly-signed requests' do
      get fedipub.node_info_url, headers: { signature: 'poop' }
      expect(response).to have_http_status :unauthorized
    end

    it 'rejects unsigned requests when signatures are required' do
      allow(Fedipub::ServerController).to receive(:require_signature?).and_return(true)
      get fedipub.node_info_url
      expect(response).to have_http_status :unauthorized
    end
  end

  describe 'GET /nodeinfo/2.0' do
    it 'renders a successful response' do
      get fedipub.show_node_info_url
      expect(response).to be_successful
    end

    it 'rejects badly-signed requests' do
      get fedipub.show_node_info_url, headers: { signature: 'poop' }
      expect(response).to have_http_status :unauthorized
    end

    it 'rejects unsigned requests when signatures are required' do
      allow(Fedipub::ServerController).to receive(:require_signature?).and_return(true)
      get fedipub.show_node_info_url
      expect(response).to have_http_status :unauthorized
    end

    it 'include software name' do
      get fedipub.show_node_info_url
      expect(response.parsed_body['software']['name']).to eq 'the-dummy-app'
    end

    it 'transforms software name to match spec regex' do
      get fedipub.show_node_info_url
      expect(response.parsed_body['software']['name']).to match(/^[a-z0-9-]+$/)
    end

    it 'does not include user data if no method is set' do
      prev = Fedipub::Configuration.actor_types.dig('User', :user_count_method)
      Fedipub::Configuration.actor_types['User'][:user_count_method] = nil
      get fedipub.show_node_info_url
      expect(response.parsed_body).not_to have_key :users
      Fedipub::Configuration.actor_types['User'][:user_count_method] = prev
    end

    context 'with some users' do
      let(:json) do
        User.delete_all # Remove seed
        FactoryBot.create :user, created_at: 1.year.ago, updated_at: 1.year.ago
        FactoryBot.create :user, created_at: 1.year.ago, updated_at: 2.months.ago
        FactoryBot.create :user, created_at: 1.year.ago, updated_at: 1.week.ago
        get fedipub.show_node_info_url
        response.parsed_body
      end

      it 'gets total count' do
        expect(json.dig('usage', 'users', 'total')).to eq 3
      end

      it 'gets monthly count' do
        expect(json.dig('usage', 'users', 'activeMonth')).to eq 1
      end

      it 'gets half year count' do
        expect(json.dig('usage', 'users', 'activeHalfyear')).to eq 2
      end
    end

    it 'shows closed registrations by default' do
      get fedipub.show_node_info_url
      expect(response.parsed_body['openRegistrations']).to be false
    end

    it 'shows open registrations if set' do
      prev = Fedipub::Configuration.open_registrations
      Fedipub::Configuration.open_registrations = true
      get fedipub.show_node_info_url
      expect(response.parsed_body['openRegistrations']).to be true
    ensure
      Fedipub::Configuration.open_registrations = prev
    end

    it 'gets open registrations from a proc' do
      prev = Fedipub::Configuration.open_registrations
      Fedipub::Configuration.open_registrations = -> { true }
      get fedipub.show_node_info_url
      expect(response.parsed_body['openRegistrations']).to be true
    ensure
      Fedipub::Configuration.open_registrations = prev
    end

    it 'includes extra nodeinfo metadata from a hash' do
      prev = Fedipub::Configuration.nodeinfo_metadata
      Fedipub::Configuration.nodeinfo_metadata = { 'faspBaseUrl' => 'https://fedi.example.com/fasp' }
      get fedipub.show_node_info_url
      expect(response.parsed_body.dig('metadata', 'faspBaseUrl')).to eq 'https://fedi.example.com/fasp'
    ensure
      Fedipub::Configuration.nodeinfo_metadata = prev
    end

    it 'includes extra nodeinfo metadata from a proc' do
      prev = Fedipub::Configuration.nodeinfo_metadata
      Fedipub::Configuration.nodeinfo_metadata = -> { { 'faspBaseUrl' => 'https://fedi.example.com/fasp' } }
      get fedipub.show_node_info_url
      expect(response.parsed_body.dig('metadata', 'faspBaseUrl')).to eq 'https://fedi.example.com/fasp'
    ensure
      Fedipub::Configuration.nodeinfo_metadata = prev
    end
  end
end
