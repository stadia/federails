require 'rails_helper'

RSpec.describe Federails::Server::FollowingsController, type: :acceptance do
  resource 'Federation/Followings', 'Followings management'

  let(:headers) { { accept: 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"' } }
  let(:user) { FactoryBot.create :user }
  let(:following) do
    target_actor = FactoryBot.create(:user).actor
    FactoryBot.create :following, actor: user.actor, target_actor: target_actor
  end

  before do
    RSpec::Rails::Api::Metadata.default_expected_content_type =
      'application/ld+json; profile="https://www.w3.org/ns/activitystreams"; charset=utf-8'
  end

  entity :following,
         '@context': { type: :string, description: 'JSON-LD contexts' },
         id:         { type: :string, description: 'Federated id for this following' },
         type:       { type: :string, description: 'Object type. Should be "Follow"' },
         actor:      { type: :string, description: 'Federated ID of the creator' },
         object:     { type: :string, description: 'Federated ID of the followed actor' }

  parameters :following_path_params,
             actor_id: { type: :integer, description: 'Actor identifier. Not the JSON-LD identifier' },
             id:       { type: :integer, description: 'Following identifier' }

  on_get '/federation/actors/:actor_id/followings/:id', 'Display a following' do
    for_code 200, expect_one: :following do |url|
      test_response_of url, path_params: { actor_id: following.actor_id, id: following.id }, headers: headers
    end

    for_code 404, with_content_type: Mime[:activitypub] do |url|
      test_response_of url, path_params: { actor_id: following.actor_id, id: 0 }, headers: headers
    end
  end
end
