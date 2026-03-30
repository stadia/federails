require 'rails_helper'

RSpec.describe 'Federation collections (liked, featured, featured_tags)', type: :request do
  let(:user) { FactoryBot.create :user }
  let(:actor) { user.federails_actor }

  describe 'GET /liked' do
    it 'renders a successful response' do
      get federails.liked_server_actor_url(actor), headers: { accept: Mime[:activitypub] }
      expect(response).to be_successful
    end

    it 'returns an OrderedCollection' do
      get federails.liked_server_actor_url(actor), headers: { accept: Mime[:activitypub] }
      json = JSON.parse(response.body) # rubocop:disable Rails/ResponseParsedBody
      expect(json['type']).to eq 'OrderedCollection'
    end
  end

  describe 'GET /featured' do
    it 'renders a successful response' do
      get federails.featured_server_actor_url(actor), headers: { accept: Mime[:activitypub] }
      expect(response).to be_successful
    end

    it 'returns an OrderedCollection' do
      get federails.featured_server_actor_url(actor), headers: { accept: Mime[:activitypub] }
      json = JSON.parse(response.body) # rubocop:disable Rails/ResponseParsedBody
      expect(json['type']).to eq 'OrderedCollection'
    end

    context 'with featured items' do
      before do
        actor.feature('https://remote.example/posts/1')
      end

      it 'includes featured items on page' do
        get federails.featured_server_actor_url(actor, page: 1), headers: { accept: Mime[:activitypub] }
        json = JSON.parse(response.body) # rubocop:disable Rails/ResponseParsedBody
        expect(json['orderedItems']).to include('https://remote.example/posts/1')
      end
    end
  end

  describe 'GET /featured_tags' do
    it 'renders a successful response' do
      get federails.featured_tags_server_actor_url(actor), headers: { accept: Mime[:activitypub] }
      expect(response).to be_successful
    end

    it 'returns an OrderedCollection' do
      get federails.featured_tags_server_actor_url(actor), headers: { accept: Mime[:activitypub] }
      json = JSON.parse(response.body) # rubocop:disable Rails/ResponseParsedBody
      expect(json['type']).to eq 'OrderedCollection'
    end

    context 'with featured tags' do
      before do
        actor.featured_tags.create!(name: 'ruby')
      end

      it 'includes featured tags on page' do
        get federails.featured_tags_server_actor_url(actor, page: 1), headers: { accept: Mime[:activitypub] }
        json = JSON.parse(response.body) # rubocop:disable Rails/ResponseParsedBody
        expect(json['orderedItems']).to include(hash_including('type' => 'Hashtag', 'name' => 'ruby'))
      end
    end
  end

  describe 'Actor JSON' do
    it 'includes liked, featured, and featuredTags URLs' do
      get federails.server_actor_url(actor), headers: { accept: Mime[:activitypub] }
      json = JSON.parse(response.body) # rubocop:disable Rails/ResponseParsedBody
      aggregate_failures do
        expect(json['liked']).to be_present
        expect(json['liked']).to include('/liked')
        expect(json['featured']).to be_present
        expect(json['featured']).to include('/featured')
        expect(json['featuredTags']).to be_present
        expect(json['featuredTags']).to include('/featured_tags')
      end
    end
  end
end
