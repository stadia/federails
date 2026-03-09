set_json_ld_context(json)
collection_id = @actor.followings_url

if params[:page].blank?
  json.id collection_id
  json.type 'OrderedCollection'
  json.totalItems @total_actors
  json.first Federails::Engine.routes.url_helpers.following_server_actor_url(@actor, page: 1)
else
  json.id Federails::Engine.routes.url_helpers.following_server_actor_url(@actor, page: params[:page])
  json.type 'OrderedCollectionPage'
  json.totalItems @total_actors
  json.next Federails::Engine.routes.url_helpers.following_server_actor_url(@actor, page: @actors.next_page) if @actors.next_page
  json.partOf collection_id
  json.orderedItems do
    json.array! @actors.map(&:federated_url)
  end
end
