require 'rails_helper'

RSpec.describe 'POST federation/actors/:actor_id/inbox with a Note to become a Comment', type: :request do
  # Small tests to check that dispatch works as intended
  describe '.dispatch_request' do
    let(:actor_urls) do
      %w[
        https://mamot.fr/users/mtancoigne
        https://mastodon.me.uk/users/Floppy
      ]
    end
    let!(:local_actor) { FactoryBot.create :local_actor }
    let(:fediverse_object) do
      {
        # Answer to https://mamot.fr/users/mtancoigne/statuses/113741447018463971,
        # which is the first Note in the discussion.
        '@context' => 'https://www.w3.org/ns/activitystreams',
        'id'       => 'https://mastodon.me.uk/users/Floppy/statuses/113741998973323773/activity',
        'type'     => 'Create',
        'actor'    => 'https://mastodon.me.uk/users/Floppy',
        'object'   => 'https://mastodon.me.uk/users/Floppy/statuses/113741998973323773',
      }.to_json
    end
    let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
    let(:make_request) do
      post federails.server_actor_inbox_url(actor_id: local_actor.id), params: fediverse_object, headers: headers
    end

    context 'with a supported Note', :doing do
      context 'when actors already exist' do
        before do
          VCR.use_cassette 'dummy/fediverse/request/get_comment_actors_200' do
            actor_urls.each { |url| Federails::Actor.find_or_create_by_federation_url url }
          end
        end

        it 'creates a Comment' do
          Post.new
          VCR.use_cassette 'dummy/fediverse/request/get_note_comment_200' do
            expect { make_request }.to change(Comment, :count).by 1
          end
        end

        it 'does not create a new actor' do
          VCR.use_cassette 'dummy/fediverse/request/get_note_comment_200' do
            expect { make_request }.not_to change(Federails::Actor, :count)
          end
        end
      end

      context 'when the actor does not exist' do
        around do |example|
          VCR.use_cassette 'dummy/fediverse/request/get_note_comment_and_actor_200' do
            example.run
          end
        end

        it 'creates the distant actors' do
          expect { make_request }.to change { Federails::Actor.distant.count }.by 2
        end

        it 'creates a Comment' do
          expect { make_request }.to change(Comment, :count).by 1
        end

        it 'creates the parent Post' do
          aggregate_failures do
            expect { make_request }.to change(Post, :count).by 1
            expect(Comment.last.post_id).to eq Post.last.id
          end
        end
      end

      context 'with a reply to a comment' do
        let(:fediverse_object) do
          # Answer to https://mastodon.me.uk/users/Floppy/statuses/113741998973323773
          {
            '@context' => 'https://www.w3.org/ns/activitystreams',
            'id'       => 'https://mamot.fr/users/mtancoigne/statuses/113742013147922180/activity',
            'type'     => 'Create',
            'actor'    => 'https://mamot.fr/users/mtancoigne',
            'object'   => 'https://mamot.fr/users/mtancoigne/statuses/113742013147922180',
          }.to_json
        end

        around do |example|
          VCR.use_cassette 'dummy/fediverse/request/get_notes_and_actors_with_parents_200' do
            example.run
          end
        end

        it 'creates all the comments, post and actors' do
          expect { make_request }.to change(Comment, :count).by(2)
                                 .and change(Post, :count).by(1)
                                 .and change(Federails::Actor, :count).by(2)
        end
      end
    end
  end
end
