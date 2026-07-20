require 'rails_helper'
require 'fedipub/data_transformer/note'

RSpec.describe '/federation/published', type: :request do
  describe 'GET /show' do
    let(:user) { FactoryBot.create :user }
    let(:actor) { user.fedipub_actor }
    let(:entity) { Fixtures::Classes::FakeArticleDataModel.create! fedipub_actor: actor, title: 'title', content: 'content', user: user }

    ACTIVITYPUB_CONTENT_TYPES.each do |accept|
      it "responds with LD in response to a #{accept} request" do
        get fedipub.server_published_url(:articles, entity), headers: { accept: Mime[:activitypub] }

        aggregate_failures do
          expect(response).to be_successful
          expect(response.content_type).to eq 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"; charset=utf-8'
        end
      end
    end
  end
end
