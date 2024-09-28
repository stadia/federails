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
