require 'rails_helper'

RSpec.describe Federails::Client::ActivitiesController, type: :controller do
  routes { Federails::Engine.routes }
  render_views

  describe 'GET #index' do
    let!(:activity) { FactoryBot.create :activity, :create }

    it 'renders activities as json' do
      get :index, format: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body

      expect(body.first).to include(
        'id'     => activity.id,
        'action' => activity.action
      )
    end
  end

  describe 'GET #feed' do
    let(:user) { User.find_by(email: 'user@example.com') }

    before { sign_in user }

    it 'renders the feed as json' do
      get :feed, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end
  end
end
