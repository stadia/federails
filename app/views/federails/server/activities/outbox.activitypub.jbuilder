set_json_ld_context(json)
collection_id = @actor.outbox_url
if params[:page].blank?
  json.id collection_id
  json.type 'OrderedCollection'
  json.totalItems @total_activities
  json.first Federails::Engine.routes.url_helpers.server_actor_outbox_url(@actor, page: 1)
  json.last @pagy.pages == 1 ? Federails::Engine.routes.url_helpers.server_actor_outbox_url(@actor, page: 1) : Federails::Engine.routes.url_helpers.server_actor_outbox_url(@actor, page: @pagy.pages)
else
  json.id Federails::Engine.routes.url_helpers.server_actor_outbox_url(@actor, page: params[:page])
  json.type 'OrderedCollectionPage'
  json.totalItems @total_activities
  json.prev Federails::Engine.routes.url_helpers.server_actor_outbox_url(@actor, page: @pagy.previous) if @pagy.previous
  json.next Federails::Engine.routes.url_helpers.server_actor_outbox_url(@actor, page: @pagy.next) if @pagy.next
  json.partOf collection_id
  json.orderedItems do
    json.array! @activities, partial: 'federails/server/activities/activity', as: :activity, context: false
  end
end
