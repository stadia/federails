module Federails
  module Server
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
      :context,
      keyword_init: true
    ) unless const_defined?(:OrderedCollectionPayload)

    class OrderedCollectionResource < BaseResource
      attribute :'@context' do |payload|
        Federails::SerializerSupport.json_ld_context if payload.context != false
      end

      attributes :id, :type, :totalItems, :first, :last, :prev, :next, :partOf, :orderedItems
    end
  end
end
