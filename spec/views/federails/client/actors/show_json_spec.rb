require 'rails_helper'

RSpec.describe 'federails/client/actors/show', type: :view do
  it 'renders the actor as json' do
    actor = FactoryBot.create(:local_actor)
    assign(:actor, actor)

    render template: 'federails/client/actors/show', formats: [:json]

    json = JSON.parse(rendered)
    aggregate_failures do
      expect(json['id']).to eq(actor.id)
      expect(json['name']).to eq(actor.name)
      expect(json['username']).to eq(actor.username)
      expect(json['federated_url']).to eq(actor.federated_url)
    end
  end
end
