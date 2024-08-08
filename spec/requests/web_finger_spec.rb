require 'rails_helper'

RSpec.describe '/well-known', type: :request do
  describe 'GET /.well-known/webfinger' do
    it 'renders a successful response given acct: URI' do
      user = FactoryBot.create :user
      get federails.webfinger_url, params: { resource: "acct:#{user.id}@localhost" }
      expect(response).to be_successful
    end

    it 'renders a successful response given HTTP URI' do
      user = FactoryBot.create :user
      get federails.webfinger_url, params: { resource: user.actor.federated_url }
      expect(response).to be_successful
    end
  end

  describe 'GET /.well-known/host-meta' do
    it 'renders a successful response' do
      get federails.host_meta_url
      expect(response).to be_successful
    end
  end
end
