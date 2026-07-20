require 'rails_helper'

module Federails
  module Client
    RSpec.describe ActorsController, type: :routing do
      describe 'routing' do
        it 'routes to #index' do
          expect(get: '/app/actors').to route_to('federails/client/actors#index')
        end

        it 'routes to #show' do
          expect(get: '/app/actors/1').to route_to('federails/client/actors#show', id: '1')
        end

        it 'routes to #lookup' do
          expect(get: '/app/actors/lookup?account=bob').to route_to('federails/client/actors#lookup', account: 'bob')
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
          expect(get: '/app/actors').not_to be_routable
        end

        it 'does not route to #show' do
          expect(get: '/app/actors/1').not_to be_routable
        end

        it 'does not route to #lookup' do
          expect(get: '/app/actors/lookup?account=bob').not_to be_routable
        end
      end
    end
  end
end
