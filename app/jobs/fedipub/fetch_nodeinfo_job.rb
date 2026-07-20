require 'fediverse/notifier'

module Fedipub
  class FetchNodeinfoJob < ApplicationJob
    # @param domain [String] Domain to create/update
    def perform(domain)
      Fedipub::Host.create_or_update domain, min_update_interval: Fedipub::Configuration.remote_entities_cache_duration
    end
  end
end
