# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/federation/inbox (shared)', type: :request do
  let(:actor) { FactoryBot.create(:local_actor) }
  let(:payload) do
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => 'https://remote.example/activity/1',
      'type' => 'Follow',
      'actor' => 'https://remote.example/actor',
      'object' => actor.federated_url,
    }.to_json
  end

  before do
    Federails::Configuration.verify_signatures = false
  end

  after do
    Federails::Configuration.verify_signatures = true
  end

  describe 'POST /federation/inbox' do
    it 'accepts valid activity with 201' do
      allow(Fediverse::Inbox).to receive(:dispatch_request).and_return(true)
      allow(Fediverse::Inbox).to receive(:maybe_forward)

      post federails.server_shared_inbox_path, params: payload, headers: { 'Content-Type' => 'application/activity+json' }

      expect(response).to have_http_status(:created)
    end

    it 'returns 415 for unsupported content type' do
      post federails.server_shared_inbox_path, params: payload, headers: { 'Content-Type' => 'text/plain' }

      expect(response).to have_http_status(:unsupported_media_type)
    end

    it 'returns 422 for invalid payload' do
      post federails.server_shared_inbox_path, params: '{}', headers: { 'Content-Type' => 'application/activity+json' }

      expect(response).to have_http_status(:unprocessable_entity).or have_http_status(:unprocessable_content)
    end

    it 'returns 200 for duplicate activity' do
      allow(Fediverse::Inbox).to receive(:dispatch_request).and_return(:duplicate)

      post federails.server_shared_inbox_path, params: payload, headers: { 'Content-Type' => 'application/activity+json' }

      expect(response).to have_http_status(:ok)
    end

    context 'when verify_signatures is true' do
      before { Federails::Configuration.verify_signatures = true }

      it 'rejects unsigned POST with 401' do
        post federails.server_shared_inbox_path, params: payload, headers: { 'Content-Type' => 'application/activity+json' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
