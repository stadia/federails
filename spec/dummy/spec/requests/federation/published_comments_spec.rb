require 'rails_helper'

RSpec.describe '/federation/published', type: :request do
  describe 'GET /federation/published/comments/:id' do
    let(:comment) { FactoryBot.create :comment }

    it 'renders a successful response' do
      get federails.server_published_url(publishable_type: 'comments', id: comment.id)

      expect(response).to be_successful
    end

    it 'includes standard JSON-LD context' do
      get federails.server_published_url(publishable_type: 'comments', id: comment.id)
      json = JSON.parse(response.body)
      expect(json['@context']).to include('https://www.w3.org/ns/activitystreams')
    end

    it 'includes additional JSON-LD context' do # rubocop:todo RSpec/MultipleExpectations
      get federails.server_published_url(publishable_type: 'comments', id: comment.id)
      json = JSON.parse(response.body)
      expect(json['@context']).to include('https://purl.archive.org/miscellany')
      expect(json['@context']).to include({ 'Hashtag' => 'as:Hashtag' })
    end

    context 'when the comment does not exist' do
      it 'renders an error' do
        get federails.server_published_url(publishable_type: 'comments', id: 'invalid')

        expect(response).to have_http_status :not_found
      end
    end
  end
end
