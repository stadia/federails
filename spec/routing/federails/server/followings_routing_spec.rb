require 'rails_helper'

module Federails
  module Server
    RSpec.describe FollowingsController, type: :routing do
      describe 'routing' do
        it 'routes to #show' do
          expect(get: '/federation/actors/1/followings/2').to route_to('federails/server/followings#show', format: :activitypub, actor_id: '1', id: '2')
        end
      end
    end
  end
end
