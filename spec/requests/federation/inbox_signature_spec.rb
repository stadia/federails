# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Inbox HTTP Signature Verification', type: :request do
  let(:actor) { FactoryBot.create :local_actor }
  let(:payload) { { '@context' => 'https://www.w3.org/ns/activitystreams', 'id' => 'https://remote.example/activity/1', 'type' => 'Follow', 'actor' => 'https://remote.example/actor', 'object' => actor.federated_url }.to_json }

  context 'when verify_signatures is true' do
    before { Federails::Configuration.verify_signatures = true }

    it 'rejects unsigned POST with 401' do
      post federails.server_actor_inbox_path(actor), params: payload, headers: { 'Content-Type' => 'application/activity+json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when verify_signatures is false' do
    it 'accepts unsigned POST' do
      allow(Fediverse::Inbox).to receive(:dispatch_request).and_return(true)
      post federails.server_actor_inbox_path(actor), params: payload, headers: { 'Content-Type' => 'application/activity+json' }
      expect(response).to have_http_status(:created)
    end
  end
end
