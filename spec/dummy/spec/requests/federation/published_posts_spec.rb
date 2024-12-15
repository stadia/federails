require 'rails_helper'

RSpec.describe '/federation/published', type: :request do
  describe 'GET /federation/published/posts/:id' do
    let(:post) { FactoryBot.create :post }

    it 'renders a successful response' do
      get federails.server_published_url(publishable_type: 'posts', id: post.id)

      expect(response).to be_successful
    end

    context 'when the post does not exist' do
      it 'renders an error' do
        get federails.server_published_url(publishable_type: 'posts', id: 'invalid')

        expect(response).to have_http_status :not_found
      end
    end
  end
end
