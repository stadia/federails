# Migration guide

## General steps

After reading the [CHANGELOG](./CHANGELOG.md) and migration guide for changes from the currently used version and the
desired one, do these steps (in the order you see fit)

- Update the gem to the desired version.
- Copy and apply new migrations 
  ```sh
  bundle exec rake fedipub:install:migrations
  ```
- Re-copy client views if you use them, and adapt them.
  ```sh
  rails generate fedipub:copy_client_views
  ```
- Follow directions of the migration guide, for every version intermediate version 

## From 0.8.0 to 0.9.0

First of all, read the **[general upgrade steps](#general-steps)**

- There are new migrations, so don't forget to _install_ them

IMPORTANT: This release renames the project from "Federails" to "Fedipub". You will need to rename usage in your app.

### Rename your code *before* installing the migrations

`rake fedipub:install:migrations` depends on `:environment`, so it boots your application first. If your
initializer still calls `Federails.config_from`, the task aborts before copying anything:

```
rake aborted!
NameError: uninitialized constant Federails
Federails.config_from "federails"
config/initializers/federails.rb:5:in '<main>'
```

So for this upgrade the order is fixed — do steps 2 and 3 below first, then install and run the migrations.

Note that the initializer and its YAML config are two separate renames:

```sh
git mv config/initializers/federails.rb config/initializers/fedipub.rb
git mv config/federails.yml config/fedipub.yml
```

`Fedipub.config_from 'fedipub'` reads `config/fedipub.yml`, so if you keep the old file name you must pass it
explicitly: `Fedipub.config_from 'federails'`.

Also update `mount Federails::Engine` to `mount Fedipub::Engine` in `config/routes.rb`.

1. If you have database references to things like `federails_actor`, you will need to create a migration in your app to rename your columns, like so:

```ruby
class RenameFederailsFieldsToFedipub < ActiveRecord::Migration[7.2]
  def change
    rename_column :posts, 'federails_actor_id', 'fedipub_actor_id'
    rename_column :comments, 'federails_actor_id', 'fedipub_actor_id'
  end
end
```

Also, if you have any polymorphic relationships in your app that refer to Fedipub models, you will need to update the type field. We recommend running something like this at application start, though exactly what you need to do will depend on your application, this is just an example:

```ruby
[
  [Comment, :commenter_type]
].each do |table, field|
  table.where(field => "Federails::Actor").update_all(field => "Fedipub::Actor")
end
```

2. If you reference it anywhere, replace the `Federails::` namespace with `Fedipub::`

3. Change method calls such as `acts_as_federails_actor` to `acts_as_fedipub_actor`, and `acts_as_federails_data` to
   `acts_as_fedipub_data`.

If you do a global search and replace for "federails" to "fedipub", ensure you DO NOT change existing migrations in your app; renaming of actual database content is handled by a new migration.

The same applies to the migrations copied from the gem: `rake fedipub:install:migrations` skips a gem migration when
your app already has one with the same name, ignoring the `.federails.` / `.fedipub.` scope suffix. That is why the
gem keeps its historical migration file names spelled "federails", and why renaming the copies already sitting in your
`db/migrate` would make the task copy `create_fedipub_actors` again on top of tables you already have. Lines like
`NOTE: Migration ..._create_federails_actors.rb from fedipub has been skipped` are the expected output, not an error.

### If your app squashed its migration history

The skip above is keyed on files, not on the database. If your app collapsed its history into a baseline
(`init_schema`-style) migration that creates the `federails_*` tables itself, the gem's historical migrations are no
longer in `db/migrate`, so nothing matches by name and `install:migrations` copies all of them back in. They then run
against tables that already exist:

```
== 20260828081723 CreateFederailsActors: migrating ===
-- create_table(:federails_actors)
PG::DuplicateTable: ERROR:  relation "federails_actors" already exists
```

This breaks a fresh `db:drop db:create db:migrate` too, because the copies sort after your baseline.

Do not delete the offending files — the next upgrade would copy them straight back. Empty them out instead, keeping
the class name so future runs skip them:

```ruby
# This migration comes from fedipub (originally 20200712133150)
# Superseded by db/migrate/<timestamp>_init_schema.rb, which already creates this schema.
class CreateFederailsActors < ActiveRecord::Migration[7.0]
  def change; end
end
```

Before doing that, confirm your baseline really does cover them — compare `connection.columns` and
`connection.indexes` for each `federails_*` table against the gem's migrations. `RenameFederailsToFedipub` renames
three indexes by their exact names (`index_federails_activities_on_entity`, `index_federails_actors_on_entity`,
`index_federails_followings_on_actor_id_and_target_actor_id`), so those have to exist under those names.

Only the rename and backfill migrations should actually execute.

### Data left behind by the rename

`RenameFederailsToFedipub` renames tables and indexes only, so polymorphic columns keep pointing at the old
namespace. `BackfillFedipubEntityTypes` takes care of `fedipub_activities.entity_type` (which holds
`Federails::Actor` for Update/Delete/Announce/Like on an actor and `Federails::Activity` for Undo); it ships with the
gem, so installing and running the migrations is enough.

Polymorphic columns in *your own* tables are not covered — see the `commenter_type` example above.

## From 0.6.2 to 0.7.0

First of all, read the **[general upgrade steps](#general-steps)**

Some client views have some fixes; update yours if you override them in your app.

## From 0.6.1 to 0.6.2

Update the gem (no migration, no changes on views, ect...).

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
