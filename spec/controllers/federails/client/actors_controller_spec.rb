require 'rails_helper'

RSpec.describe Federails::Client::ActorsController, type: :controller do
  routes { Federails::Engine.routes }
  render_views

  describe 'GET #index' do
    let!(:local_actor) { FactoryBot.create(:local_actor) }
    let!(:distant_actor) { FactoryBot.create(:distant_actor) }

    it 'renders actors as json' do
      get :index, format: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      expect(body.map { |item| item['id'] }).to include(local_actor.id, distant_actor.id)
    end

    it 'filters to local actors when requested' do
      get :index, params: { local_only: '1' }, format: :json

      body = JSON.parse(response.body)
      expect(body).to all(include('local' => true))
    end
  end

  describe 'GET #show' do
    let(:actor) { FactoryBot.create(:local_actor) }

    it 'renders the actor as json' do
      get :show, params: { id: actor.to_param }, format: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      aggregate_failures do
        expect(body['id']).to eq(actor.id)
        expect(body['username']).to eq(actor.username)
        expect(body['federated_url']).to eq(actor.federated_url)
      end
    end

    it 'renders a gone error for tombstoned actors' do
      actor.tombstone!

      get :show, params: { id: actor.to_param }, format: :json

      expect(response).to have_http_status(:gone)
      expect(JSON.parse(response.body)).to include('error' => I18n.t('controller.actors.gone'))
    end
  end
end
