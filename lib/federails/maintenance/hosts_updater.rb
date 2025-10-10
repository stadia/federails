module Federails
  module Maintenance
    class HostsUpdater
      class << self
        # Update information for all known hosts, and complete if some are missing
        def run(cache_interval: nil)
          cache_interval ||= Federails::Configuration.remote_entities_cache_duration

          domains = Federails::Actor.distant.distinct(:server).pluck(:server) + Federails::Host.pluck(:domain)
          domains.uniq!

          domains.each do |domain|
            Federails::Host.create_or_update domain, min_update_interval: cache_interval
          end
        end
      end
    end
  end
end
