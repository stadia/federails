# rbs_inline: enabled

module Fedipub
  module Server
    unless const_defined?(:NodeinfoPayload)
      NodeinfoPayload = Struct.new(
        :software_name,       #: untyped
        :software_version,    #: untyped
        :open_registrations,  #: untyped
        :has_user_counts,     #: untyped
        :total,               #: untyped
        :active_month,        #: untyped
        :active_halfyear,     #: untyped
        :metadata             #: untyped
      )
    end

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
