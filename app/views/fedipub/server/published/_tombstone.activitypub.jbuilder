set_json_ld_context(json)

json.id publishable.federated_url
json.type 'Tombstone'
json.deleted publishable.fedipub_tombstoned_at
json.formerType publishable.fedipub_data_configuration[:handles]
