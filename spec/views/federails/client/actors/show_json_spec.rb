require 'rails_helper'

RSpec.describe 'federails/client/actors/show', type: :view do
  it 'renders the actor as json' do
    actor = FactoryBot.create(:local_actor)
    json = JSON.parse(Federails::Client::ActorResource.new(actor).serialize)
    aggregate_failures do
      expect(json['id']).to eq(actor.id)
      expect(json['name']).to eq(actor.name)
      expect(json['username']).to eq(actor.username)
      expect(json['federated_url']).to eq(actor.federated_url)
    end
  end
end
