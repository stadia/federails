set_json_ld_context(json)
json.id @collection_id
json.type 'OrderedCollection'
json.totalItems @total_actors
json.first @first_page
json.last @last_page
