module Federails
  module Server
    # rubocop:disable Naming/MethodName
    unless const_defined?(:OrderedCollectionPayload)
      class OrderedCollectionPayload
        def initialize(attributes)
          @attributes = attributes
        end

        def id = @attributes[:id]
        def type = @attributes[:type]
        def totalItems = @attributes[:totalItems]
        def first = @attributes[:first]
        def last = @attributes[:last]
        def prev = @attributes[:prev]
        def next = @attributes[:next]
        def partOf = @attributes[:partOf]
        def orderedItems = @attributes[:orderedItems]
        def context = @attributes[:context]
      end
    end

    class OrderedCollectionResource < BaseResource
      attribute :@context do |payload|
        Federails::SerializerSupport.json_ld_context if payload.context != false
      end

      attributes :id, :type, :totalItems, :first, :last, :prev, :next, :partOf, :orderedItems
    end
    # rubocop:enable Naming/MethodName
  end
end
