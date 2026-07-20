require 'rails_helper'

module Fedipub
  module Server
    RSpec.describe FollowingsController, type: :routing do
      describe 'routing' do
        it 'routes to #show' do
          expect(get: '/federation/actors/1/followings/2').to route_to('fedipub/server/followings#show', format: :activitypub, actor_id: '1', id: '2')
        end
      end
    end
  end
end
