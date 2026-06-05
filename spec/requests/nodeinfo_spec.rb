require 'rails_helper'

RSpec.describe '/nodeinfo', type: :request do
  describe 'GET /.well-known/nodeinfo' do
    it 'renders a successful response' do
      get federails.node_info_url
      expect(response).to be_successful
    end
  end

  describe 'GET /nodeinfo/2.0' do
    it 'renders a successful response' do
      get federails.show_node_info_url
      expect(response).to be_successful
    end

    it 'include software name' do
      get federails.show_node_info_url
      expect(response.parsed_body['software']['name']).to eq 'the-dummy-app'
    end

    it 'transforms software name to match spec regex' do
      get federails.show_node_info_url
      expect(response.parsed_body['software']['name']).to match(/^[a-z0-9-]+$/)
    end

    it 'does not include user data if no method is set' do
      prev = Federails::Configuration.actor_types.dig('User', :user_count_method)
      Federails::Configuration.actor_types['User'][:user_count_method] = nil
      get federails.show_node_info_url
      expect(response.parsed_body).not_to have_key :users
      Federails::Configuration.actor_types['User'][:user_count_method] = prev
    end

    context 'with some users' do
      let(:json) do
        User.delete_all # Remove seed
        FactoryBot.create :user, created_at: 1.year.ago, updated_at: 1.year.ago
        FactoryBot.create :user, created_at: 1.year.ago, updated_at: 2.months.ago
        FactoryBot.create :user, created_at: 1.year.ago, updated_at: 1.week.ago
        get federails.show_node_info_url
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
      get federails.show_node_info_url
      expect(response.parsed_body['openRegistrations']).to be false
    end

    it 'shows open registrations if set' do
      prev = Federails::Configuration.open_registrations
      Federails::Configuration.open_registrations = true
      get federails.show_node_info_url
      expect(response.parsed_body['openRegistrations']).to be true
    ensure
      Federails::Configuration.open_registrations = prev
    end

    it 'gets open registrations from a proc' do
      prev = Federails::Configuration.open_registrations
      Federails::Configuration.open_registrations = -> { true }
      get federails.show_node_info_url
      expect(response.parsed_body['openRegistrations']).to be true
    ensure
      Federails::Configuration.open_registrations = prev
    end

    it 'includes extra nodeinfo metadata from a hash' do
      prev = Federails::Configuration.nodeinfo_metadata
      Federails::Configuration.nodeinfo_metadata = { 'faspBaseUrl' => 'https://fedi.example.com/fasp' }
      get federails.show_node_info_url
      expect(response.parsed_body.dig('metadata', 'faspBaseUrl')).to eq 'https://fedi.example.com/fasp'
    ensure
      Federails::Configuration.nodeinfo_metadata = prev
    end

    it 'includes extra nodeinfo metadata from a proc' do
      prev = Federails::Configuration.nodeinfo_metadata
      Federails::Configuration.nodeinfo_metadata = -> { { 'faspBaseUrl' => 'https://fedi.example.com/fasp' } }
      get federails.show_node_info_url
      expect(response.parsed_body.dig('metadata', 'faspBaseUrl')).to eq 'https://fedi.example.com/fasp'
    ensure
      Federails::Configuration.nodeinfo_metadata = prev
    end
  end
end
