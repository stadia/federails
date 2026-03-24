set_json_ld_context(json)
json.id send(url_helper, actor)
json.type 'OrderedCollection'
json.totalItems collection.total_count
json.first send(url_helper, actor, page: 1)
json.last send(url_helper, actor, page: collection.total_pages)
