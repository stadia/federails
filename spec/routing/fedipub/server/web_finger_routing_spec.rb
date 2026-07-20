require 'rails_helper'

module Federails
  module Server
    RSpec.describe WebFingerController, type: :routing do
      let(:find_url) { { url: '/.well-known/webfinger?resource=someone@here.com', target: ['federails/server/web_finger#find', { resource: 'someone@here.com' }] } }
      let(:host_meta_url) { { url: '/.well-known/host-meta', target: ['federails/server/web_finger#host_meta'] } }

      describe 'routing' do
        it 'routes to #find' do
          expect(get: find_url[:url]).to route_to(*find_url[:target])
        end

        it 'routes to #host_meta' do
          expect(get: host_meta_url[:url]).to route_to(*host_meta_url[:target])
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

        it 'does not route to #find' do
          expect(get: find_url[:url]).not_to route_to(*find_url[:target])
        end

        it 'does not route to #host_meta' do
          expect(get: host_meta_url[:url]).not_to route_to(*host_meta_url[:target])
        end
      end
    end
  end
end
