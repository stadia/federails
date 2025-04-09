# Migration guide

## General steps

After reading the [CHANGELOG](./CHANGELOG.md) and migration guide for changes from the currently used version and the
desired one, do these steps (in the order you see fit)

- Update the gem to the desired version.
- Copy and apply new migrations 
  ```sh
  bundle exec rails federails:install:migrations
  ```
- Re-copy client views if you use them, and adapt them.
  ```sh
  rails generate federails:copy_client_views
  ```
- Follow directions of the migration guide, for every version intermediate version 

## Next

## From 0.6.0 to 0.6.1

Update the gem (no migration, no changes on views, ect...).

## From 0.5.0 to 0.6.0

First of all, read the **[general upgrade steps](#general-steps)**

- `actor_type` was added to `Federails::Actor`. Once the migration is applied, update all actors:
  ```sh
  rake federails:sync_actors
  ```
  or in one of your migrations:
  ```rb
  Federails::Maintenance::ActorsUpdater.run
  ```


## From 0.4.0 to 0.5.0

First of all, read the **[general upgrade steps](#general-steps)**

This release contains only new features and should be safe to apply.

## From 0.3.0 to 0.4.0

First of all, read the **[general upgrade steps](#general-steps)**

- Relation to Federails actor has changed in related entities, from `actor` to `federails_actor`. Update your usages accordingly.
- Method `create_actor`, included on related entities has been renamed to `create_federails_actor`. Update your usages accordingly.
- Rename `Federails::Entity` to `Federails::ActorEntity`.
- Rename `Federails::Configuration.register_entity` to `Federails::Configuration.register_actor_class`
- Rename `Federails::Configuration.entity_types` to `Federails::Configuration.actor_types`
- If you use `Federails::Configuration.actor_types[entity_type]`, you can replace it with `Federails.actor_entity(class_or_instance)`

## From 0.2.0 to 0.3.0

First of all, read the **[general upgrade steps](#general-steps)**

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
