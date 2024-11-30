require 'rails_helper'

RSpec.describe Federails::Server::PublishedController, type: :acceptance do
  resource 'Federation/Publishable', "Display ActivityPub representations of application's published DataEntity"

  let(:headers) { { accept: 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"' } }
  let(:user) { FactoryBot.create :user }
  let(:publishable) { Fixtures::Classes::FakeDataModel.create! user: user, title: 'The title', content: 'The content' }

  before do
    RSpec::Rails::Api::Metadata.default_expected_content_type =
      'application/ld+json; profile="https://www.w3.org/ns/activitystreams"; charset=utf-8'
  end

  entity :publishable_entity,
         '@context': { type: :string, description: 'JSON-LD contexts' },
         id:         { type: :string, description: 'Federated ID of the DataEntity' },
         actor:      { type: :string, description: 'Federated ID of the creator' }

  parameters :publishable_path_params,
             publishable_type: { type: :string, description: 'DataEntity type, same as configured with `:route_path_segment`' },
             id:               { type: :integer, description: 'Unique DataEntity identifier' }

  on_get '/federation/published/:publishable_type/:id', 'Display an ActivityPub representation of a published DataEntity', 'Additional properties may vary depending on the object type' do
    for_code 200, expect_one: :publishable_entity do |url|
      test_response_of url, path_params: { publishable_type: 'fake_data', id: publishable.id }, headers: headers
    end

    for_code 404, with_content_type: Mime[:activitypub] do |url|
      test_response_of url, path_params: { publishable_type: 'unsupported', id: 1 }, headers: headers
    end
  end
end
