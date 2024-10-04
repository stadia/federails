require 'rails_helper'

RSpec.describe Federails::Server::ActivitiesController, type: :acceptance do
  resource 'Federation/Activities', 'Activities management'
  let(:headers) { { accept: 'application/ld+json; profile="https://www.w3.org/ns/activitystreams"' } }
  let(:actor) { FactoryBot.create(:user).actor }
  let(:following) { FactoryBot.create :following, actor: actor }
  let(:following_activity) { following.activities.last }

  before do
    RSpec::Rails::Api::Metadata.default_expected_content_type =
      'application/ld+json; profile="https://www.w3.org/ns/activitystreams"; charset=utf-8'
  end

  activity_base = {
    id:     { type: :string, description: 'Federated id for this activity' },
    type:   { type: :string, description: 'Activity type' },
    actor:  { type: :string, description: 'Federated actor identifier' },
    object: { type: :string, description: 'Federated target object identifier' },
    to:     { type: :array, description: 'List of targeted actors', of: :string },
    cc:     { type: :array, description: 'Complementary list', of: :string },
  }

  entity :activity, activity_base
  entity :activity_with_context, activity_base.merge({
                                                       '@context': { type: :string, description: 'JSON-LD contexts' },
                                                     })

  entity :ordered_collection_page,
         # Base
         id:           { type: :string, description: 'Unique identifier' },
         type:         { type: :string, description: 'Object type (OrderedCollectionPage)' },
         # CollectionPage
         partOf:       { type: :string, description: 'URL to the collection to which this CollectionPage belong' },
         next:         { type: :string, required: false, description: 'URL to the next page of items' },
         prev:         { type: :string, required: false, description: 'URL to the previous page of items' },
         # OrderedCollection/Collection
         totalItems:   { type: :integer, description: 'Total number of following/followers in this collection' },
         orderedItems: { type: :array, description: 'List of activities on current page', of: :activity }
  entity :ordered_collection,
         '@context': { type: :string, description: 'JSON-LD context' },
         # Base
         id:         { type: :string, description: 'Unique identifier' },
         type:       { type: :string, description: 'Object type (OrderedCollection)' },
         # CollectionPage (except items)
         totalItems: { type: :integer, description: 'Total number of pages in this collection' },
         current:    { type: :object, description: 'OrderedCollectionPage with list of actor IDs', attributes: :ordered_collection_page },
         first:      { type: :string, description: 'URL to the furthest preceding page' },
         last:       { type: :string, description: 'URL to the furthest proceeding page' }

  parameters :inbox_request_params, activity_base.merge({
                                                          '@context': { type: :string, description: 'JSON-LD contexts' },
                                                        })

  on_get '/federation/actors/:actor_id/activities/:id', 'Display an activity' do
    path_params fields: {
      actor_id: { type: :integer, description: 'Actor identifier. Not the JSON-LD identifier' },
      id:       { type: :integer, description: 'Activity identifier' },
    }

    for_code 200, expect_one: :activity_with_context do |url|
      test_response_of url, path_params: { actor_id: following_activity.actor.to_param, id: following_activity.to_param }, headers: headers
    end

    for_code 404, with_content_type: Mime[:activitypub] do |url|
      test_response_of url, path_params: { actor_id: following_activity.actor.to_param, id: 0 }, headers: headers
    end
  end

  on_get '/federation/actors/:actor_id/outbox', "Actor's outbox" do
    path_params fields: {
      actor_id: { type: :integer, description: 'Actor identifier. Not the JSON-LD identifier' },
    }

    for_code 200, expect_one: :ordered_collection do |url|
      test_response_of url, path_params: { actor_id: following_activity.actor.to_param }, headers: headers
    end

    for_code 404, with_content_type: Mime[:activitypub] do |url|
      test_response_of url, path_params: { actor_id: 0 }, headers: headers
    end
  end

  on_post '/federation/actors/:actor_id/inbox', "Actor's inbox" do # rubocop:todo RSpec/MultipleMemoizedHelpers
    let(:distant_actor) { FactoryBot.create :distant_actor }
    let(:inbox_payload) do
      {
        '@context' => 'https://www.w3.org/ns/activitystreams',
        'id'       => federails.server_actor_activity_url(actor, following.activities.last),
        'type'     => 'Create',
        'actor'    => distant_actor.federated_url,
        'object'   => federails.server_actor_following_url(actor, following),
        'to'       => ['https://www.w3.org/ns/activitystreams#Public'],
        'cc'       => [actor.followers_url],
      }
    end

    path_params fields: {
      actor_id: { type: :integer, description: 'Actor identifier. Not the JSON-LD identifier' },
    }
    request_params defined: :inbox_request_params

    for_code 201, with_content_type: Mime[:activitypub] do |url|
      allow(Fediverse::Inbox).to receive(:dispatch_request).and_return true
      test_response_of url, path_params: { actor_id: distant_actor.to_param }, payload: inbox_payload, headers: headers
    end

    for_code 422, with_content_type: Mime[:activitypub] do |url|
      test_response_of url, path_params: { actor_id: distant_actor.to_param }, payload: {}, headers: headers
    end
  end
end
