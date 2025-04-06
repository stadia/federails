json.set! '@context', [
  'https://www.w3.org/ns/activitystreams',
  'https://w3id.org/security/v1',
]

json.id publishable.federated_url
json.type 'Tombstone'
json.deleted publishable.federails_tombstoned_at
json.formerType publishable.federails_data_configuration[:handles]
