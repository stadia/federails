require 'rails_helper'

module Federails
  module Client
    RSpec.describe ActivitiesController, type: :routing do
      describe 'routing' do
        it 'routes to #index' do
          expect(get: '/app/activities').to route_to('federails/client/activities#index')
        end

        it 'routes to #index via actors' do
          expect(get: '/app/actors/1/activities').to route_to('federails/client/activities#index', actor_id: '1')
        end

        it 'routes to #feed' do
          expect(get: '/app/feed').to route_to('federails/client/activities#feed')
        end
      end

      context 'when client routes are disabled' do
        before do
          @old_state = Federails.configuration.client_routes_path
          Federails.configuration.client_routes_path = nil
          Rails.application.reload_routes!
        end

        after do
          Federails.configuration.client_routes_path = @old_state
          Rails.application.reload_routes!
        end

        it 'does not route to #index' do
          expect(get: '/app/activities').not_to be_routable
        end

        it 'does not route to #index via actors' do
          expect(get: '/app/actors/1/activities').not_to be_routable
        end

        it 'does not route to #feed' do
          expect(get: '/app/feed').not_to be_routable
        end
      end
    end
  end
end
