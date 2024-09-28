require 'rails_helper'

RSpec.describe Federails::Server::NodeinfoController, type: :acceptance do
  resource 'Nodeinfo', 'Node info endpoints'
  let(:headers) { { accept: 'application/json; profile="http://nodeinfo.diaspora.software/ns/schema/2.0#"' } }

  before do
    RSpec::Rails::Api::Metadata.default_expected_content_type = 'application/json; profile="http://nodeinfo.diaspora.software/ns/schema/2.0#"; charset=utf-8'
  end

  entity :node_info,
         links: { type: :array, description: '', of: {
           rel:  { type: :string, description: 'Schema URL' },
           href: { type: :string, description: 'Resource URI' },
         } }

  entity :node_info_v2,
         version:           { type: :string, description: 'NodeInfo version. Should be 2.0' },
         software:          { type: :object, description: 'Software information', attributes: {
           name:    { type: :string, description: 'Software name' },
           version: { type: :string, description: 'Version running' },
         } },
         protocols:         { type: :array, description: 'List of supported protocols' },
         services:          { type: :object, description: 'Available services', attributes: {
           inbound:  { type: :array, description: '' },
           outbound: { type: :array, description: '' },
         } },
         openRegistrations: { type: :boolean, description: 'Flag stating if registrations are open' },
         usage:             { type: :object, description: 'Usage statistics', attributes: {
           users: { type: :object, description: 'Various informations about users', attributes: {
             total:          { type: :integer, description: 'Total amount of users' },
             activeMonth:    { type: :integer, description: 'Amount of users subscribed this mounth' },
             activeHalfyear: { type: :integer, description: 'Amount of users subscribed in the last 6 months' },
           } },
         } },
         metadata:          { type: :object, description: 'Various metadata.' }

  on_get '/.well-known/nodeinfo', 'List of links leading to this node infos' do
    for_code 200, expect_one: :node_info do |url|
      test_response_of url, headers: headers
    end
  end

  on_get '/nodeinfo/2.0', 'Node info' do
    for_code 200, expect_one: :node_info_v2 do |url|
      test_response_of url, headers: headers
    end
  end
end
