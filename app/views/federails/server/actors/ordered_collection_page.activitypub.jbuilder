set_json_ld_context(json)
json.type 'OrderedCollectionPage'
json.id @current_page
json.partOf @collection_id
json.first @first_page
json.last @last_page
json.next @next_page if @next_page
json.prev @prev_page if @prev_page
json.totalItems @total_actors
json.orderedItems do
  json.array! @actors.map(&:federated_url)
end
