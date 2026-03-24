module Federails
  module Server
    NodeinfoIndexPayload = Struct.new(:href) unless const_defined?(:NodeinfoIndexPayload)

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
