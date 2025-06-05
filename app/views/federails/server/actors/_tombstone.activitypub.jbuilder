set_json_ld_context(json)

json.id actor.federated_url
json.type 'Tombstone'
json.deleted actor.tombstoned_at
json.formerType actor.actor_type
