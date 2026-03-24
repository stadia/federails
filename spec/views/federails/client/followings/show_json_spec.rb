require 'rails_helper'

RSpec.describe 'federails/client/followings/show', type: :view do
  it 'renders the following as json' do
    following = FactoryBot.create(:following)
    assign(:following, following)

    render template: 'federails/client/followings/show', formats: [:json]

    json = JSON.parse(rendered)
    aggregate_failures do
      expect(json['id']).to eq(following.id)
      expect(json['actor_id']).to eq(following.actor_id)
      expect(json['target_actor_id']).to eq(following.target_actor_id)
      expect(json['status']).to eq(following.status)
    end
  end
end
