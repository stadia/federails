context = true unless context == false
set_json_ld_context(json) if context

publishable.to_activitypub_object.each_pair do |key, value|
  json.set! key, value
end

json.id publishable.federated_url
json.actor publishable.fedipub_actor.federated_url
json.to [Fediverse::Collection::PUBLIC]
json.cc [publishable.fedipub_actor.followers_url]
