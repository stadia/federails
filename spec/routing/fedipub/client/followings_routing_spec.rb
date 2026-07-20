require 'rails_helper'

module Federails
  module Client
    RSpec.describe FollowingsController, type: :routing do
      describe 'routing' do
        it 'routes to #follow' do
          expect(post: '/app/followings/follow').to route_to('federails/client/followings#follow')
        end

        it 'routes to #accept' do
          expect(put: '/app/followings/1/accept').to route_to('federails/client/followings#accept', id: '1')
        end

        it 'routes to #create' do
          expect(post: '/app/followings').to route_to('federails/client/followings#create')
        end

        it 'routes to #destroy' do
          expect(delete: '/app/followings/1').to route_to('federails/client/followings#destroy', id: '1')
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

        it 'does not route to #follow' do
          expect(post: '/app/followings/follow').not_to be_routable
        end

        it 'does not route to #accept' do
          expect(put: '/app/followings/1/accept').not_to be_routable
        end

        it 'does not route to #create' do
          expect(post: '/app/followings').not_to be_routable
        end

        it 'does not route to #destroy' do
          expect(delete: '/app/followings/1').not_to be_routable
        end
      end
    end
  end
end
