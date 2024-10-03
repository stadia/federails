require 'rails_helper'

RSpec.describe '/well-known', type: :request do
  describe 'GET /.well-known/webfinger' do
    let(:user) { FactoryBot.create :user }

    it 'renders a successful response given acct: URI' do
      get federails.webfinger_url, params: { resource: "acct:#{user.id}@localhost" }
      expect(response).to be_successful
    end

    it 'renders a successful response given HTTP URI' do
      get federails.webfinger_url, params: { resource: user.actor.federated_url }
      expect(response).to be_successful
    end

    ['application/jrd+json', 'application/json'].each do |accept|
      it "responds with JRD in response to a #{accept} request" do
        get federails.webfinger_url, params: { resource: user.actor.federated_url }, headers: { accept: accept }
        expect(response.content_type).to eq 'application/jrd+json; charset=utf-8'
      end

      it "responds with 404 in response to a #{accept} request for a nonexistent account" do
        get federails.webfinger_url, params: { resource: 'acct:nobody@localhost' }, headers: { accept: accept }
        expect(response).to be_not_found
      end
    end

    context 'when checking content' do
      let(:result) do
        get federails.webfinger_url, params: { resource: "acct:#{user.id}@localhost" }, headers: { accept: accept }
        JSON.parse response.body # rubocop:disable Rails/ResponseParsedBody
      end

      it 'specifies subject' do
        expect(result['subject']).to eq "acct:#{user.id}@localhost"
      end

      it 'includes HTML profile link' do # rubocop:disable RSpec/MultipleExpectations
        html_profile = result['links'].find { |x| x['rel'] == 'https://webfinger.net/rel/profile-page' }
        expect(html_profile).to be_present
        expect(html_profile['type']).to eq 'text/html'
        expect(html_profile['href']).to eq user.actor.profile_url
      end

      it 'includes self link to activitypub actor' do # rubocop:disable RSpec/MultipleExpectations
        self_link = result['links'].find { |x| x['rel'] == 'self' }
        expect(self_link).to be_present
        expect(self_link['type']).to eq 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"'
        expect(self_link['href']).to eq user.actor.federated_url
      end
    end
  end

  describe 'GET /.well-known/host-meta' do
    it 'renders a successful response' do
      get federails.host_meta_url
      expect(response).to be_successful
    end

    ['application/xrd+xml', 'application/xml'].each do |accept|
      it "responds with XRD in response to a #{accept} request" do
        get federails.host_meta_url, headers: { accept: accept }
        expect(response.content_type).to eq 'application/xrd+xml; charset=utf-8'
      end
    end
  end
end
