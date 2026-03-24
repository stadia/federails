require 'rails_helper'
require 'federails/data_transformer/note'

RSpec.describe '/federation/published', type: :request do
  describe 'GET /show' do
    let(:user) { FactoryBot.create :user }
    let(:actor) { user.federails_actor }
    let(:entity) { Fixtures::Classes::FakeArticleDataModel.create! federails_actor: actor, title: 'title', content: 'content', user: user }

    ACTIVITYPUB_CONTENT_TYPES.each do |accept|
      it "responds with LD in response to a #{accept} request" do
        get federails.server_published_url(:articles, entity), headers: { accept: Mime[:activitypub] }

        aggregate_failures do
          expect(response).to be_successful
          expect(response.content_type).to eq 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"; charset=utf-8'
        end
      end
    end

    it 'returns a publishable object with required fields' do
      get federails.server_published_url(:articles, entity), headers: { accept: Mime[:activitypub] }
      json = JSON.parse(response.body) # rubocop:disable Rails/ResponseParsedBody
      aggregate_failures do
        expect(json['type']).to eq 'Note'
        expect(json['id']).to eq entity.federated_url
        expect(json['actor']).to eq actor.federated_url
      end
    end

    it 'returns a JSON error body for unknown publishable types' do
      get federails.server_published_url(publishable_type: 'unsupported', id: entity.id, format: :json)

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq 'Invalid unsupported type'
    end

    it 'returns a JSON error body for missing publishables' do
      get federails.server_published_url(publishable_type: 'articles', id: 'missing', format: :json)

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to include("Couldn't find")
    end

    context 'when the publishable is soft deleted' do
      let(:deleted_entity) do
        Fixtures::Classes::FakeArticleDataModel.create!(
          federails_actor: actor,
          title: 'title',
          content: 'content',
          user: user,
          deleted_at: Time.current
        )
      end

      it 'returns a gone status with no body for ActivityPub requests' do
        get federails.server_published_url(:articles, deleted_entity), headers: { accept: Mime[:activitypub] }

        expect(response).to have_http_status(:gone)
        expect(response.body).to be_blank
      end

      it 'returns a JSON error body for JSON requests' do
        get federails.server_published_url(publishable_type: 'articles', id: deleted_entity.id, format: :json)

        expect(response).to have_http_status(:gone)
        expect(JSON.parse(response.body)['error']).to eq 'Federails::DataEntity::TombstonedError'
      end
    end
  end
end
