set_json_ld_context(json)
json.type 'OrderedCollectionPage'
json.id send(url_helper, actor, page: collection.current_page)
json.partOf send(url_helper, actor)
json.first send(url_helper, actor, page: 1)
json.last send(url_helper, actor, page: collection.total_pages)
json.next send(url_helper, actor, page: collection.next_page) if collection.next_page
json.prev send(url_helper, actor, page: collection.prev_page) if collection.prev_page
json.totalItems collection.total_count
json.orderedItems do
  items_block.call(json, collection)
end
