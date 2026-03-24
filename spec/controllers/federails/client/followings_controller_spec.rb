require 'rails_helper'

RSpec.describe Federails::Client::FollowingsController, type: :controller do
  routes { Federails::Engine.routes }
  render_views

  let(:user) { User.find_by(email: 'user@example.com') }
  let(:target_actor) { FactoryBot.create(:user).federails_actor }

  before do
    sign_in user
    controller.singleton_class.define_method(:following_url) { |following| "/followings/#{following.id}" }
  end

  describe 'POST #create' do
    it 'creates a following and renders json' do
      expect do
        post :create, params: { following: { target_actor_id: target_actor.id } }, format: :json
      end.to change(Federails::Following, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body

      aggregate_failures do
        expect(body['actor_id']).to eq(user.federails_actor.id)
        expect(body['target_actor_id']).to eq(target_actor.id)
      end
    end

    it 'renders errors as json when invalid' do
      post :create, params: { following: { target_actor_id: nil } }, format: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to have_key('target_actor')
    end
  end

  describe 'PUT #accept' do
    let(:incoming_following) { FactoryBot.create :following, actor: target_actor, target_actor: user.federails_actor }

    it 'accepts and renders the following as json' do
      put :accept, params: { id: incoming_following.to_param }, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('accepted')
    end
  end

  describe 'DELETE #destroy' do
    let!(:following) { FactoryBot.create :following, actor: user.federails_actor, target_actor: target_actor }

    it 'returns no content' do
      delete :destroy, params: { id: following.to_param }, format: :json

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_blank
    end
  end
end
