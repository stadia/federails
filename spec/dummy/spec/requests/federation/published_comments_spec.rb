require 'rails_helper'

RSpec.describe '/federation/published', type: :request do
  describe 'GET /federation/published/comments/:id' do
    let(:comment) { FactoryBot.create :comment }

    it 'renders a successful response' do
      get federails.server_published_url(publishable_type: 'comments', id: comment.id)

      expect(response).to be_successful
    end

    context 'when the comment does not exist' do
      it 'renders an error' do
        get federails.server_published_url(publishable_type: 'comments', id: 'invalid')

        expect(response).to have_http_status :not_found
      end
    end
  end
end
