json.set! '@context', 'https://www.w3.org/ns/activitystreams'

json.id actor.federated_url
json.name actor.name
json.type actor.entity_configuration[:actor_type]
json.preferredUsername actor.username
json.inbox actor.inbox_url
json.outbox actor.outbox_url
json.followers actor.followers_url
json.following actor.followings_url
json.url actor.profile_url
