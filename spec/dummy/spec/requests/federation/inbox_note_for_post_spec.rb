require 'rails_helper'

RSpec.describe 'POST federation/actors/:actor_id/inbox with a Note to become a Post', type: :request do
  # Small tests to check that dispatch works as intended
  describe '.dispatch_request' do
    let(:distant_actor_url) { 'https://mamot.fr/users/mtancoigne' }
    let!(:local_actor) { FactoryBot.create :local_actor }
    let(:fediverse_object) do
      {
        '@context' => 'https://www.w3.org/ns/activitystreams',
        'id'       => 'https://mamot.fr/users/mtancoigne/statuses/113741447018463971/activity',
        'type'     => 'Create',
        'actor'    => 'https://mamot.fr/users/mtancoigne',
        'object'   => 'https://mamot.fr/users/mtancoigne/statuses/113741447018463971',
      }.to_json
    end
    let(:headers) do
      {
        'Content-Type' => 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"',
        'Accept'       => 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"',
      }
    end
    let(:make_request) do
      post federails.server_actor_inbox_url(actor_id: local_actor.id), params: fediverse_object, headers: headers
    end

    context 'with a supported Note' do
      it 'rejects non-ActivityPub content types' do
        post(
          federails.server_actor_inbox_url(actor_id: local_actor.id),
          params:  fediverse_object,
          headers: headers.merge('Content-Type' => 'application/json')
        )

        expect(response).to have_http_status(:unsupported_media_type)
      end

      context 'when JSON-LD compaction fails' do
        before do
          VCR.use_cassette 'fediverse/request/get_actor_200' do
            Federails::Actor.find_or_create_by_federation_url distant_actor_url
          end

          allow(JSON::LD::API).to receive(:compact).and_raise(
            JSON::LD::JsonLdError::ProtectedTermRedefinition,
            'protected term redefinition'
          )
        end

        it 'still creates a Post from the inbox payload' do
          VCR.use_cassette 'dummy/fediverse/request/get_note_200' do
            expect { make_request }.to change(Post, :count).by 1
          end
        end

        it 'returns created' do
          VCR.use_cassette 'dummy/fediverse/request/get_note_200' do
            make_request
            expect(response).to have_http_status(:created)
          end
        end
      end

      context 'when actor already exist' do
        before do
          VCR.use_cassette 'fediverse/request/get_actor_200' do
            Federails::Actor.find_or_create_by_federation_url distant_actor_url
          end
        end

        it 'creates a Post' do
          VCR.use_cassette 'dummy/fediverse/request/get_note_200' do
            expect { make_request }.to change(Post, :count).by 1
          end
        end

        it 'does not create a new actor' do
          VCR.use_cassette 'dummy/fediverse/request/get_note_200' do
            expect { make_request }.not_to change(Federails::Actor, :count)
          end
        end
      end

      context 'when the actor does not exist' do
        around do |example|
          VCR.use_cassette 'dummy/fediverse/request/get_note_and_actor_200' do
            example.run
          end
        end

        it 'creates the distant actor' do
          expect { make_request }.to change { Federails::Actor.distant.count }.by 1
        end

        it 'creates a Post' do
          expect { make_request }.to change(Post, :count).by 1
        end
      end
    end
  end
end
