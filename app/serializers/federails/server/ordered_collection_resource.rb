module Federails
  module Server
    unless const_defined?(:OrderedCollectionPayload)
      OrderedCollectionPayload = Struct.new(
        :id,
        :type,
        :totalItems,
        :first,
        :last,
        :prev,
        :next,
        :partOf,
        :orderedItems,
        :context
      )
    end

    class OrderedCollectionResource < BaseResource
      attribute :@context do |payload|
        Federails::SerializerSupport.json_ld_context if payload.context != false
      end

      attributes :id, :type, :totalItems, :first, :last, :prev, :next, :partOf, :orderedItems
    end
  end
end
