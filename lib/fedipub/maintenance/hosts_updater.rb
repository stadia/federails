# typed: true
# rbs_inline: enabled

module Fedipub
  module Maintenance
    class HostsUpdater
      class << self
        # Update information for all known hosts, and complete if some are missing
        def run(cache_interval: nil)
          cache_interval ||= Fedipub::Configuration.remote_entities_cache_duration

          domains = Fedipub::Actor.distant.distinct.pluck(:server) + Fedipub::Host.pluck(:domain)
          domains.uniq!

          domains.each do |domain|
            Fedipub::Host.create_or_update domain, min_update_interval: cache_interval
          end
        end
      end
    end
  end
end
