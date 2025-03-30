require 'rails_helper'

RSpec.describe '/well-known', type: :request do
  describe 'GET /.well-known/webfinger' do
    let(:user) { FactoryBot.create :user }

    it 'renders a successful response given acct: URI' do
      get federails.webfinger_url, params: { resource: "acct:#{user.id}@localhost" }
      expect(response).to be_successful
    end

    it 'renders a not found response given an @ address' do
      expect do
        get federails.webfinger_url, params: { resource: "@#{user.id}@localhost" }
      end.to raise_error ActiveRecord::RecordNotFound
    end

    it 'renders a not found response given a bare address' do
      expect do
        get federails.webfinger_url, params: { resource: "#{user.id}@localhost" }
      end.to raise_error ActiveRecord::RecordNotFound
    end

    it 'renders a successful response given HTTP URI' do
      get federails.webfinger_url, params: { resource: user.federails_actor.federated_url }
      expect(response).to be_successful
    end

    ['application/jrd+json', 'application/json'].each do |accept|
      it "responds with JRD in response to a #{accept} request" do
        get federails.webfinger_url, params: { resource: user.federails_actor.federated_url }, headers: { accept: accept }
        expect(response.content_type).to eq 'application/jrd+json; charset=utf-8'
      end

      it "responds with 404 in response to a #{accept} request for a nonexistent account" do
        get federails.webfinger_url, params: { resource: 'acct:nobody@localhost' }, headers: { accept: accept }
        expect(response).to be_not_found
      end
    end

    context 'with a tombstoned actor' do
      let(:actor) { user.federails_actor.tombstone! }

      ['application/jrd+json', 'application/json'].each do |accept|
        it "returns an error page to a #{accept} request with an URL resource" do
          get federails.webfinger_url, params: { resource: actor.federated_url }, headers: { accept: accept }
          expect(response).to have_http_status :gone
        end

        it "returns an error page to a #{accept} request with an 'acct:' resource" do
          get federails.webfinger_url, params: { resource: actor.acct_uri }, headers: { accept: accept }
          expect(response).to have_http_status :gone
        end
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
        expect(html_profile['href']).to eq user.federails_actor.profile_url
      end

      it 'includes self link to activitypub actor' do # rubocop:disable RSpec/MultipleExpectations
        self_link = result['links'].find { |x| x['rel'] == 'self' }
        expect(self_link).to be_present
        expect(self_link['type']).to eq 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"'
        expect(self_link['href']).to eq user.federails_actor.federated_url
      end

      it 'includes ostatus subscribe template for remote following' do # rubocop:disable RSpec/MultipleExpectations
        remote_follow = result['links'].find { |x| x['rel'] == 'http://ostatus.org/schema/1.0/subscribe' }
        expect(remote_follow).to be_present
        expect(remote_follow['template']).to eq 'http://www.example.com/app/followings/new?uri={uri}'
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
