context = true unless context == false
set_json_ld_context(json) if context

json.id following.federated_url
json.type 'Follow'
json.actor following.actor.federated_url
json.object following.target_actor.federated_url
