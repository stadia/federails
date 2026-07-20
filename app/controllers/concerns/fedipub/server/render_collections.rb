module Fedipub
  module Server
    module RenderCollections
      extend ActiveSupport::Concern

      def render_collection(actor:, collection:, url_helper:, &items_block)
        if params[:page].present?
          render_collection_page(actor: actor, collection: collection, url_helper: url_helper, items_block: items_block)
        else
          render 'fedipub/server/shared/ordered_collection', locals: { collection: collection, url_helper: url_helper, actor: actor }
        end
      end

      def render_collection_page(collection:, actor:, url_helper:, items_block:)
        render 'fedipub/server/shared/ordered_collection_page', locals: { collection: collection, url_helper: url_helper, actor: actor, items_block: items_block }
      end
    end
  end
end
