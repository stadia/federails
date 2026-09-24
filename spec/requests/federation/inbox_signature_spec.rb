# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Inbox HTTP Signature Verification', type: :request do
  let(:actor) { FactoryBot.create :local_actor }
  let(:inbox_path) { fedipub.server_actor_inbox_path(actor) }
  let(:payload) { { '@context' => 'https://www.w3.org/ns/activitystreams', 'id' => 'https://remote.example/activity/1', 'type' => 'Follow', 'actor' => 'https://remote.example/actor', 'object' => actor.federated_url }.to_json }

  def request_digest(body)
    "SHA-256=#{Base64.strict_encode64(OpenSSL::Digest.new('SHA256').digest(body))}"
  end

  def base_signature_headers(body, digest: true)
    {
      'Host'         => 'www.example.com',
      'Date'         => Time.current.httpdate,
      'Digest'       => (request_digest(body) if digest),
      'Content-Type' => 'application/activity+json',
    }.compact
  end

  def build_signature_request(body, digest: true)
    Faraday.default_connection.build_request(:post) do |r|
      r.url "http://www.example.com#{inbox_path}"
      r.body = body
      base_signature_headers(body, digest: digest).each { |key, value| r.headers[key] = value }
    end
  end

  def signature_headers_for(signing_actor, body, legacy_signature: false, digest: true)
    request = build_signature_request(body, digest: digest)
    Fediverse::Signature.sign(sender: signing_actor, request: request, legacy_signature: legacy_signature)
    request.headers.to_h
  end

  shared_examples 'a signed inbox' do
    it 'rejects unsigned POST with 401' do
      post inbox_path, params: payload, headers: { 'Content-Type' => 'application/activity+json' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects a signed request when the payload actor does not match the signed actor' do
      signing_actor = FactoryBot.create(:user).fedipub_actor

      allow(Fedipub::Actor).to receive(:find_or_create_by_federation_url)
        .with(signing_actor.federated_url).and_return(signing_actor)

      post inbox_path, params: payload, headers: signature_headers_for(signing_actor, payload)

      expect(response).to have_http_status(:unauthorized)
    end

    it 'logs failure context including remote_ip and payload actor on signature failure' do
      allow(Fedipub.logger).to receive(:warn)

      post inbox_path,
           params:  payload,
           headers: { 'Content-Type' => 'application/activity+json' }

      expect(response).to have_http_status(:unauthorized)
      expect(Fedipub.logger).to have_received(:warn) do |&block|
        log = block.call
        expect(log).to include(
          message:   a_string_starting_with('Signature verification failed'),
          remote_ip: '127.0.0.1',
          actor:     'https://remote.example/actor'
        )
      end
    end

    it 'tolerates a non-JSON body when logging failure context' do
      allow(Fedipub.logger).to receive(:warn)

      post inbox_path,
           params:  'not-json-at-all',
           headers: { 'Content-Type' => 'application/activity+json' }

      expect(response).to have_http_status(:unauthorized)
      expect(Fedipub.logger).to have_received(:warn) do |&block|
        log = block.call
        expect(log).to include(
          message: a_string_starting_with('Signature verification failed'),
          actor:   nil
        )
      end
    end

    [false, true].each do |legacy_signature|
      it "accepts a valid #{legacy_signature ? 'draft-cavage-12' : 'RFC9421'} signed request whose payload actor matches the signed actor" do
        signing_actor = FactoryBot.create(:user).fedipub_actor
        matching_payload = {
          '@context' => 'https://www.w3.org/ns/activitystreams',
          'id'       => 'https://remote.example/activity/2',
          'type'     => 'Follow',
          'actor'    => signing_actor.federated_url,
          'object'   => actor.federated_url,
        }.to_json

        allow(Fedipub::Actor).to receive(:find_or_create_by_federation_url)
          .with(signing_actor.federated_url).and_return(signing_actor)
        allow(Fediverse::Inbox).to receive_messages(dispatch_request: true, maybe_forward: nil)

        post inbox_path,
             params:  matching_payload,
             headers: signature_headers_for(signing_actor, matching_payload, legacy_signature: legacy_signature)

        expect(response).to have_http_status(:created)
        expect(Fediverse::Inbox).to have_received(:dispatch_request)
      end
    end

    it 'rejects a signed request whose body does not match its digest' do
      signing_actor = FactoryBot.create(:user).fedipub_actor
      allow(Fedipub::Actor).to receive(:find_or_create_by_federation_url)
        .with(signing_actor.federated_url).and_return(signing_actor)

      post inbox_path,
           params:  payload.sub('Follow', 'Delete'),
           headers: signature_headers_for(signing_actor, payload)

      expect(response).to have_http_status(:unauthorized)
    end

    context 'with a matching signed payload' do
      let(:signing_actor) { FactoryBot.create(:user).fedipub_actor }
      let(:matching_payload) do
        {
          '@context' => 'https://www.w3.org/ns/activitystreams',
          'id'       => 'https://remote.example/activity/3',
          'type'     => 'Follow',
          'actor'    => signing_actor.federated_url,
          'object'   => actor.federated_url,
        }.to_json
      end

      before do
        allow(Fedipub::Actor).to receive(:find_or_create_by_federation_url)
          .with(signing_actor.federated_url).and_return(signing_actor)
        allow(Fediverse::Inbox).to receive_messages(dispatch_request: true, maybe_forward: nil)
      end

      it 'accepts an RFC9421 request carrying only Content-Digest' do
        post inbox_path, params: matching_payload, headers: signature_headers_for(signing_actor, matching_payload, digest: false)
        expect(response).to have_http_status(:created)
      end

      it 'rejects a request where one of the digest headers does not match the body' do
        headers = signature_headers_for(signing_actor, matching_payload).merge('Digest' => request_digest('tampered'))
        post inbox_path, params: matching_payload, headers: headers
        expect(response).to have_http_status(:unauthorized)
      end

      context 'when the payload claims to come from another actor' do
        let(:victim) { FactoryBot.create(:user).fedipub_actor }
        let(:victim_payload) { JSON.parse(matching_payload).merge('actor' => victim.federated_url).to_json }

        it 'uses the key owner, not a decoy draft-cavage-12 keyId, as the signer' do
          headers = signature_headers_for(signing_actor, victim_payload, legacy_signature: true)
          headers['Signature'] = headers['Signature'].sub('keyId=', %(xkeyId="#{victim.key_id}",keyId=))
          post inbox_path, params: victim_payload, headers: headers
          expect(response).to have_http_status(:unauthorized)
        end

        it 'uses the key owner, not a decoy RFC9421 parameter, as the signer' do
          # Hand-built signature, so the decoy parameter can come before the real keyid
          content_digest = "sha-256=:#{Base64.strict_encode64(OpenSSL::Digest.new('SHA256').digest(victim_payload))}:"
          params = %[("@method" "@target-uri" "content-digest");created=#{Time.now.to_i};dkeyid="#{victim.key_id}";keyid="#{signing_actor.key_id}"]
          base = [
            '"@method": POST',
            %("@target-uri": http://www.example.com#{inbox_path}),
            %("content-digest": #{content_digest}),
            %("@signature-params": #{params}),
          ].join("\n")
          key = OpenSSL::PKey::RSA.new(signing_actor.private_key, Rails.application.credentials.secret_key_base)
          signature = Base64.strict_encode64(key.sign(OpenSSL::Digest.new('SHA256'), base))

          post inbox_path, params: victim_payload, headers: base_signature_headers(victim_payload, digest: false).merge(
            'Content-Digest'  => content_digest,
            'Signature-Input' => "sig1=#{params}",
            'Signature'       => "sig1=:#{signature}:"
          )
          expect(response).to have_http_status(:unauthorized)
        end
      end

      it 'rejects a draft-cavage-12 signature with duplicated keyId parameters' do
        headers = signature_headers_for(signing_actor, matching_payload, legacy_signature: true)
        headers['Signature'] = %(keyId="https://remote.example/actor#main-key",#{headers['Signature']})
        post inbox_path, params: matching_payload, headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  context 'when verify_signatures is true' do
    before { Fedipub::Configuration.verify_signatures = true }

    context 'with an actor inbox' do
      it_behaves_like 'a signed inbox'
    end

    context 'with the shared inbox' do
      let(:inbox_path) { fedipub.server_shared_inbox_path }

      it_behaves_like 'a signed inbox'
    end
  end

  context 'when verify_signatures is false' do
    it 'accepts unsigned POST' do
      allow(Fediverse::Inbox).to receive(:dispatch_request).and_return(true)
      post inbox_path, params: payload, headers: { 'Content-Type' => 'application/activity+json' }
      expect(response).to have_http_status(:created)
    end
  end
end
