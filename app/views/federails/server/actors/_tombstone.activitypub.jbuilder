json.set! '@context', [
  'https://www.w3.org/ns/activitystreams',
  'https://w3id.org/security/v1',
]

json.id actor.federated_url
json.type 'Tombstone'
json.deleted actor.tombstoned_at
json.formerType actor.actor_type
