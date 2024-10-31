# Migration guide

## Next

First of all, read the [CHANGELOG](./CHANGELOG.md)

- Deprecated configuration options were removed; leading to a change in migrations. You will _need_ to update existing
  migrations to hardcode the `Federails.configuration.user_table` to what you previously used, in:
  - `db/migrate<timestamp>_create_federails_actors.rb`
  - `db/migrate<timestamp>_change_actor_entity_rel_to_polymorphic.rb`
- If you used the `user_profile_url_method` configuration option, remove it and use the `acts_as_federails_actor`'s
  `profile_url_method` parameter.
