require 'rails_helper'

RSpec.describe '/users', type: :request do
  let(:user) { FactoryBot.create :user }

  describe 'GET /show' do
    it 'renders a successful response' do
      get user_url(user)
      expect(response).to be_successful
    end
  end
end
