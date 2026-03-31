# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Inbox HTTP Signature Verification', type: :request do
  let(:actor) { FactoryBot.create :local_actor }
  let(:payload) { { '@context' => 'https://www.w3.org/ns/activitystreams', 'id' => 'https://remote.example/activity/1', 'type' => 'Follow', 'actor' => 'https://remote.example/actor', 'object' => actor.federated_url }.to_json }

  def request_digest(body)
    "SHA-256=#{Base64.strict_encode64(OpenSSL::Digest.new('SHA256').digest(body))}"
  end

  def base_signature_headers(body)
    {
      'Host'         => 'www.example.com',
      'Date'         => Time.current.httpdate,
      'Digest'       => request_digest(body),
      'Content-Type' => 'application/activity+json',
    }
  end

  def build_signature_request(body)
    Faraday.default_connection.build_request(:post) do |r|
      r.url federails.server_actor_inbox_path(actor)
      r.body = body
      base_signature_headers(body).each { |key, value| r.headers[key] = value }
    end
  end

  def signature_headers_for(signing_actor, body)
    request = build_signature_request(body)
    request.headers['Signature'] = Fediverse::Signature.sign(sender: signing_actor, request: request)
    request.headers.slice('Host', 'Date', 'Digest', 'Signature', 'Content-Type')
  end

  context 'when verify_signatures is true' do
    before { Federails::Configuration.verify_signatures = true }

    it 'rejects unsigned POST with 401' do
      post federails.server_actor_inbox_path(actor), params: payload, headers: { 'Content-Type' => 'application/activity+json' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects a signed request when the payload actor does not match the signed actor' do
      signing_actor = FactoryBot.create(:user).federails_actor

      allow(Federails::Actor).to receive(:find_or_create_by_federation_url)
        .with(signing_actor.federated_url).and_return(signing_actor)

      post federails.server_actor_inbox_path(actor), params: payload, headers: signature_headers_for(signing_actor, payload)

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
