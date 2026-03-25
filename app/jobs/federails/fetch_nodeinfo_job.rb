require 'fediverse/notifier'

module Federails
  class FetchNodeinfoJob < ApplicationJob
    # @param domain [String] Domain to create/update
    def perform(domain)
      Federails::Host.create_or_update domain, min_update_interval: Federails::Configuration.remote_entities_cache_duration
    end
  end
end
