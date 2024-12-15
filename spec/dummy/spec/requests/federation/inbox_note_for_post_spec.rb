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
    let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
    let(:make_request) do
      post federails.server_actor_inbox_url(actor_id: local_actor.id), params: fediverse_object, headers: headers
    end

    context 'with a supported Note', :doing do
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
