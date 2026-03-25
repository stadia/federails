module Federails
  module Server
    module RenderCollections
      extend ActiveSupport::Concern

      included do
        # Ensure the Payload struct and Resource are loaded
        require_dependency 'federails/server/ordered_collection_resource'
      end

      private

      def render_collection(actor:, collection:, url_helper:, &items_block)
        pagy, paged = pagy(collection)

        payload = if params[:page].present?
                    collection_page_payload(actor: actor, pagy: pagy, paged: paged, url_helper: url_helper, &items_block)
                  else
                    collection_summary_payload(actor: actor, pagy: pagy, url_helper: url_helper)
                  end

        render_serialized(
          Federails::Server::OrderedCollectionResource,
          payload,
          content_type: Mime[:activitypub]
        )
      end

      def collection_summary_payload(actor:, pagy:, url_helper:)
        Federails::Server::OrderedCollectionPayload.new(
          id:         url_for_collection(url_helper, actor),
          type:       'OrderedCollection',
          totalItems: pagy.count,
          first:      url_for_collection(url_helper, actor, page: 1),
          last:       url_for_collection(url_helper, actor, page: [pagy.pages, 1].max)
        )
      end

      def collection_page_payload(actor:, pagy:, paged:, url_helper:, &items_block)
        Federails::Server::OrderedCollectionPayload.new(
          id:           url_for_collection(url_helper, actor, page: params[:page]),
          type:         'OrderedCollectionPage',
          totalItems:   pagy.count,
          first:        url_for_collection(url_helper, actor, page: 1),
          last:         url_for_collection(url_helper, actor, page: [pagy.pages, 1].max),
          prev:         pagy.previous ? url_for_collection(url_helper, actor, page: pagy.previous) : nil,
          next:         pagy.next ? url_for_collection(url_helper, actor, page: pagy.next) : nil,
          partOf:       url_for_collection(url_helper, actor),
          orderedItems: items_block.call(paged)
        )
      end

      def url_for_collection(url_helper, actor, **params)
        Federails::Engine.routes.url_helpers.send(url_helper, actor, **params)
      end
    end
  end
end
