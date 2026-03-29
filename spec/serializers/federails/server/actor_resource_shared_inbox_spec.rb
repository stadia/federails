require 'rails_helper'

RSpec.describe 'Actor JSON endpoints.sharedInbox', type: :request do
  let(:user) { FactoryBot.create(:user) }
  let(:actor) { user.federails_actor }

  it 'includes endpoints.sharedInbox' do
    get federails.server_actor_path(actor), headers: { 'Accept' => 'application/activity+json' }
    json = JSON.parse(response.body)
    expect(json['endpoints']).to be_a(Hash)
    expect(json['endpoints']['sharedInbox']).to be_present
    expect(json['endpoints']['sharedInbox']).to include('/inbox')
  end
end
