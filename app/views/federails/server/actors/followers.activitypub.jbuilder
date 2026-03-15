set_json_ld_context(json)
collection_id = @actor.followers_url
if params[:page].blank?
  json.id collection_id
  json.type 'OrderedCollection'
  json.totalItems @total_actors
  json.first Federails::Engine.routes.url_helpers.followers_server_actor_url(@actor, page: 1)
  json.last @actors.total_pages == 1 ? Federails::Engine.routes.url_helpers.followers_server_actor_url(@actor, page: 1) : Federails::Engine.routes.url_helpers.followers_server_actor_url(@actor, page: @actors.total_pages)
else
  json.id Federails::Engine.routes.url_helpers.followers_server_actor_url(@actor, page: params[:page])
  json.type 'OrderedCollectionPage'
  json.totalItems @total_actors
  json.prev Federails::Engine.routes.url_helpers.followers_server_actor_url(@actor, page: @actors.prev_page) if @actors.prev_page
  json.next Federails::Engine.routes.url_helpers.followers_server_actor_url(@actor, page: @actors.next_page) if @actors.next_page
  json.partOf collection_id
  json.orderedItems do
    json.array! @actors.map(&:federated_url)
  end
end
