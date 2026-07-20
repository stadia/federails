actor_data = actor.entity&.to_activitypub_object || {}

set_json_ld_context(
  json,
  additional: [
    'https://w3id.org/security/v1',
    actor_data.delete(:@context),
  ]
)

json.id actor.federated_url
json.name actor.name
json.type actor.actor_type
json.preferredUsername actor.username
json.inbox actor.inbox_url
json.outbox actor.outbox_url
json.followers actor.followers_url
json.following actor.followings_url
json.url actor.profile_url
if actor.public_key
  json.publicKey do
    json.id actor.key_id
    json.owner actor.federated_url
    json.publicKeyPem actor.public_key
  end
end
json.merge! actor_data
