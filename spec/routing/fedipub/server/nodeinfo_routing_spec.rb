require 'rails_helper'

module Federails
  module Server
    RSpec.describe NodeinfoController, type: :routing do
      let(:index_url) { { url: '/.well-known/nodeinfo', target: ['federails/server/nodeinfo#index'] } }
      let(:show_url) { { url: '/nodeinfo/2.0', target: ['federails/server/nodeinfo#show'] } }

      describe 'routing' do
        it 'routes to #index' do
          expect(get: index_url[:url]).to route_to(*index_url[:target])
        end

        it 'routes to #show' do
          expect(get: show_url[:url]).to route_to(*show_url[:target])
        end
      end

      context 'when discovery is disabled' do
        before do
          @old_state = Federails.configuration.enable_discovery
          Federails.configuration.enable_discovery = false
          Rails.application.reload_routes!
        end

        after do
          Federails.configuration.enable_discovery = @old_state
          Rails.application.reload_routes!
        end

        it 'does not route to #index' do
          expect(get: index_url[:url]).not_to route_to(*index_url[:target])
        end

        it 'does not route to #show' do
          expect(get: show_url[:url]).not_to route_to(*show_url[:target])
        end
      end
    end
  end
end
