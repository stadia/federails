module Federails
  module Server
    NodeinfoPayload = Struct.new(
      :software_name,
      :software_version,
      :open_registrations,
      :has_user_counts,
      :total,
      :active_month,
      :active_halfyear,
      :metadata,
      keyword_init: true
    ) unless const_defined?(:NodeinfoPayload)

    class NodeinfoResource < BaseResource
      attribute :version do
        '2.0'
      end

      attribute :software do |payload|
        {
          name:    payload.software_name,
          version: payload.software_version,
        }
      end

      attribute :protocols do
        ['activitypub']
      end

      attribute :services do
        {
          inbound:  [],
          outbound: [],
        }
      end

      attribute :openRegistrations, &:open_registrations

      attribute :usage do |payload|
        next unless payload.has_user_counts

        {
          users: {
            total:          payload.total,
            activeMonth:    payload.active_month,
            activeHalfyear: payload.active_halfyear,
          },
        }
      end

      attribute :metadata, &:metadata
    end
  end
end
