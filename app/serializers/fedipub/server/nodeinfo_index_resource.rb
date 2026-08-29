# rbs_inline: enabled

module Fedipub
  module Server
    unless const_defined?(:NodeinfoIndexPayload)
      NodeinfoIndexPayload = Struct.new(
        :href #: untyped
      )
    end

    class NodeinfoIndexResource < BaseResource
      attribute :links do |payload|
        [
          {
            rel:  'http://nodeinfo.diaspora.software/ns/schema/2.0',
            href: payload.href,
          },
        ]
      end
    end
  end
end
