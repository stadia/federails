require 'rails_helper'

RSpec.describe '/well-known', type: :request do
  describe 'GET /.well-known/webfinger' do
    let(:user) { FactoryBot.create :user }

    it 'renders a successful response given acct: URI' do
      get fedipub.webfinger_url, params: { resource: "acct:#{user.id}@localhost" }
      expect(response).to be_successful
    end

    it 'rejects badly-signed requests' do
      get fedipub.webfinger_url, params: { resource: "acct:#{user.id}@localhost" }, headers: { signature: 'poop' }
      expect(response).to have_http_status :unauthorized
    end

    it 'rejects unsigned requests when signatures are required' do
      allow(Fedipub::ServerController).to receive(:require_signature?).and_return(true)
      get fedipub.webfinger_url, params: { resource: "acct:#{user.id}@localhost" }
      expect(response).to have_http_status :unauthorized
    end

    it 'renders a not found response given an @ address' do
      expect do
        get fedipub.webfinger_url, params: { resource: "@#{user.id}@localhost" }
      end.to raise_error ActiveRecord::RecordNotFound
    end

    it 'renders a not found response given a bare address' do
      expect do
        get fedipub.webfinger_url, params: { resource: "#{user.id}@localhost" }
      end.to raise_error ActiveRecord::RecordNotFound
    end

    it 'renders a successful response given HTTP URI' do
      get fedipub.webfinger_url, params: { resource: user.fedipub_actor.federated_url }
      expect(response).to be_successful
    end

    ['application/jrd+json', 'application/json'].each do |accept|
      it "responds with JRD in response to a #{accept} request" do
        get fedipub.webfinger_url, params: { resource: user.fedipub_actor.federated_url }, headers: { accept: accept }
        expect(response.content_type).to eq 'application/jrd+json; charset=utf-8'
      end

      it "responds with 404 in response to a #{accept} request for a nonexistent account" do
        get fedipub.webfinger_url, params: { resource: 'acct:nobody@localhost' }, headers: { accept: accept }
        expect(response).to be_not_found
        if accept == 'application/json'
          expect(response.parsed_body['error']).to eq 'ActiveRecord::RecordNotFound'
        else
          expect(response.body).to be_blank
        end
      end
    end

    context 'when looking up application actor by acct: URI' do
      before do
        get fedipub.webfinger_url, params: { resource: Fedipub::Actor.application_actor.at_address(prefix: 'acct:') }
      end

      it 'renders a successful response' do
        expect(response).to be_successful
      end
    end

    context 'when looking up application actor in line with FEP-d556' do
      before do
        get fedipub.webfinger_url, params: { resource: 'http://localhost' }
      end

      it 'renders a successful response' do
        expect(response).to be_successful
      end

      it 'confirms requested subject' do
        expect(response.parsed_body['subject']).to eq 'http://localhost'
      end

      it 'has correct rel type' do
        link = response.parsed_body['links'].find { |link| link['rel'] == 'https://www.w3.org/ns/activitystreams#Service' }
        expect(link).to be_present
      end

      it 'includes href to application actor' do
        link = response.parsed_body['links'].first
        expect(link['href']).to match(%r{http://localhost/federation/actors/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}})
      end
    end

    context 'when the local host contains regexp metacharacters' do
      before do
        allow(Fedipub::Utils::Host).to receive(:localhost).and_return('example.com')
        allow(Fedipub::Actor).to receive(:find_by_federation_url!).and_raise(ActiveRecord::RecordNotFound)
      end

      it 'does not treat a look-alike host as the application actor' do
        get fedipub.webfinger_url, params: { resource: 'http://exampleXcom' }, headers: { accept: 'application/jrd+json' }
        expect(response).to have_http_status :not_found
      end
    end

    context 'with a tombstoned actor' do
      let(:actor) { user.fedipub_actor.tombstone! }

      ['application/jrd+json', 'application/json'].each do |accept|
        it "returns an error page to a #{accept} request with an URL resource" do
          get fedipub.webfinger_url, params: { resource: actor.federated_url }, headers: { accept: accept }
          expect(response).to have_http_status :gone
          if accept == 'application/json'
            expect(response.parsed_body['error']).to eq 'Fedipub::Actor::TombstonedError'
          else
            expect(response.body).to be_blank
          end
        end

        it "returns an error page to a #{accept} request with an 'acct:' resource" do
          get fedipub.webfinger_url, params: { resource: actor.acct_uri }, headers: { accept: accept }
          expect(response).to have_http_status :gone
          if accept == 'application/json'
            expect(response.parsed_body['error']).to eq 'Fedipub::Actor::TombstonedError'
          else
            expect(response.body).to be_blank
          end
        end
      end
    end

    context 'when checking content' do
      let(:result) do
        get fedipub.webfinger_url, params: { resource: "acct:#{user.id}@localhost" }, headers: { accept: accept }
        response.parsed_body
      end

      it 'specifies subject' do
        expect(result['subject']).to eq "acct:#{user.id}@localhost"
      end

      it 'includes HTML profile link' do
        html_profile = result['links'].find { |x| x['rel'] == 'https://webfinger.net/rel/profile-page' }
        expect(html_profile).to be_present
        expect(html_profile['type']).to eq 'text/html'
        expect(html_profile['href']).to eq user.fedipub_actor.profile_url
      end

      it 'includes self link to activitypub actor' do
        self_link = result['links'].find { |x| x['rel'] == 'self' }
        expect(self_link).to be_present
        expect(self_link['type']).to eq 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"'
        expect(self_link['href']).to eq user.fedipub_actor.federated_url
      end

      it 'includes ostatus subscribe template for remote following' do
        remote_follow = result['links'].find { |x| x['rel'] == 'http://ostatus.org/schema/1.0/subscribe' }
        expect(remote_follow).to be_present
        expect(remote_follow['template']).to eq 'http://localhost:3000/app/followings/new?uri={uri}'
      end
    end
  end

  describe 'GET /.well-known/host-meta' do
    it 'renders a successful response' do
      get fedipub.host_meta_url
      expect(response).to be_successful
    end

    it 'includes the lrdd template in the XRD body' do
      get fedipub.host_meta_url

      expect(response.body).to include('rel="lrdd"')
      expect(response.body).to include('resource={uri}')
    end

    it 'rejects badly-signed requests' do
      get fedipub.host_meta_url, headers: { signature: 'poop' }
      expect(response).to have_http_status :unauthorized
    end

    it 'rejects unsigned requests when signatures are required' do
      allow(Fedipub::ServerController).to receive(:require_signature?).and_return(true)
      get fedipub.host_meta_url
      expect(response).to have_http_status :unauthorized
    end

    ['application/xrd+xml', 'application/xml'].each do |accept|
      it "responds with XRD in response to a #{accept} request" do
        get fedipub.host_meta_url, headers: { accept: accept }
        expect(response.content_type).to eq 'application/xrd+xml; charset=utf-8'
      end
    end
  end
end
