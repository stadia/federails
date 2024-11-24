# Migration guide

## Next

- Relation to Federails actor has changed in related entities, from `actor` to `federails_actor`. Update your usages accordingly.
- Method `create_actor`, included on related entities has been renamed to `create_federails_actor`. Update your usages accordingly.
- Rename `Federails::Entity` to `Federails::ActorEntity`.
- Rename `Federails::Configuration.register_entity` to `Federails::Configuration.register_actor_class`


## From 0.2.0 to 0.3.0

First of all, read the [CHANGELOG](./CHANGELOG.md)

- Deprecated configuration options were removed; leading to a change in migrations. You will _need_ to update existing
  migrations to hardcode the `Federails.configuration.user_table` to what you previously used, in:
  - `db/migrate<timestamp>_create_federails_actors.rb`
  - `db/migrate<timestamp>_change_actor_entity_rel_to_polymorphic.rb`
- If you used the `user_profile_url_method` configuration option, remove it and use the `acts_as_federails_actor`'s
  `profile_url_method` parameter.
- `acts_as_federails_actor`'s `name_field` is now required. If you used the default value you should use the value used 
  as `Federails::Configuration.user_name_field` as replacement.
- `acts_as_federails_actor`'s `username_field` is now required. If you used the default value you should use the value used
  as `Federails::Configuration.user_username_field` as replacement.
- In models including `Federails::Entity`, manually call `acts_as_federails_actor` to configure it properly if it's not
  yet done.  
