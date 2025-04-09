# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!--
Quick remainder of the possible sections:
-----------------------------------------
### Added
  for new features.
### Changed
  for changes in existing functionality.
### Deprecated
  for soon-to-be removed features.
### Removed
  for now removed features.
### Fixed
  for any bug fixes.
### Security
  in case of vulnerabilities.
### Maintenance
  in case of rework, dependencies change

Please, keep them in this order when updating.

Breaking changes should be prefixed by `[**BREAKING**]` (without the quotes), to stand out.
-->

## [Unreleased]

## [0.6.1] 2025-04-09

### Fixed

- Actors: don't use entity attributes if there isn't one available

## [0.6.0] 2025-04-07

### Added

- `Federails::Configuration#open_registrations` now supports a proc in addition to booleans.
- `Federails::Actor` now stores the actor's type (`actor_type`)
- `Federails::Maintenance::ActorsUpdater` was added to update distant actors
- Rake task `federails:sync_actors` was added to update distant actors from CLI
- Added support for `Delete` activities on:
  - `Actor`: soft-deletes the actor; returns 410 _gone_ responses on webfinger and Actor's `show` view
  - `Following`: destroys the following
  - `DataEntity`: triggers a hook so implementers can do what they want. Soft-deletions are also supported.

### Changed

- Renamed `Fediverse::Inbox#handle_accept_request` private method to `handle_accept_follow_request`
- Renamed `Fediverse::Inbox#handle_undo_request` private method to `handle_undo_follow_request`

### Fixed

- `sleeping_king_studios-yard` repository has been renamed to `sleeping_king_studios-docs`. A gem has been released 
- [#25](https://gitlab.com/experimentslabs/federails/-/issues/25) - `Actor#local?` now resolves with a new `local` flag 
  on `Actor`, so it is now reliable.
- Distant actors can now have local entities. Override `create_federails_actor_as_local?` in your models to determine
  if associated actor is local or not (defaults to `true`)
- Stop creating Activities when receiving distant following requests

### Maintenance

- CI now runs against multiple Ruby versions
- CI now runs against multiple Rails versions

## [0.5.0] 2025-01-22

### Added

- `Federails::Actor`: Add `.distant` scope to select distant actors
- `Federails::Request`: Add `.dereference` method to... dereference an object
- New feature: Federated entities. This allows model configuration to ease the process of creating Fediverse entities 
  from local content, and database entries from Fediverse content. When configured:
  - "Create" activities will be created on data creation 
  - Incoming "Create" activities will be dispatched on supported models to create data locally 
  - "Update" activities will be created on data update 
  - Incoming "Update" activities will be dispatched on supported models to update (or create if missing) data locally
  - Ability to support the same Fediverse type with multiple models (note: only one model finally handles the object, 
    check documentation for more)
- Data transformer for Notes: `Federails::DataTransformer::Note`, to ease transforming local data to Fediverse Notes
- Server: new "published" controller to render published `Federails::DataEntity` as federated object. This controller 
  will answer to the `federated_url` generated for local content.
- New helper module with methods to find local data from an ActivityPub object: `Federails::Utils::Object`:
  - `find_or_initialize(object_or_id)` returns nil when object is not found remotely
  - `find_or_initialize!(object_or_id)` raises an error when object is not found remotely
  - `find_or_create!(object_or_id)` raises an error when object is not found remotely
  - `timestamp_attributes(hash)` returns hash with `created_at`/`updated_at` attributes from the ActivityPub object

## [0.4.0] 2024-12-02

As we're still in a kind of early development, some changes to Federails internals are listed.

### Added

- Added `Federails.actor_entity(class_or_instance)` method which returns the configuration

### Changed

- Methods included in `Federails::Entity` are renamed with `federails` in them to avoid confusion and make projects with _actors_ able to use the gem
- [**BREAKING**] Concern `Federails::Entity` has been renamed to `Federails::ActorEntity`
- Internal method `Federails::Configuration.register_entity` has been renamed to `Federails::Configuration.register_actor_class`.
- [**BREAKING**] Configuration key `Federails::Configuration.entity_types` has been renamed to `Federails::Configuration.actor_types`

## [0.3.0] 2024-11-23

### Added

- Base controller for client controllers can be specified to something different from `ActionController::Base` with the 
  `base_client_controller` option
- New generator: `federails:copy_client_views`, that copies all the client views in `app/views/federails/client` for override
- Added `auto_create_actors` option for `acts_as_federails_actor` method to disable automatic actor creation.
- Added helper method `Federails.actor_entity?` to check if a given class/instance may have associated actors
- Dynamic dispatch of activities with `after_activity_received` (e.g.: `after_activity_received 'Create', 'Note', :create_note`)
- Ability to add custom data to actor responses
- Handle URI-only objects in dynamic dispatch

### Changed

- Client: reworked the views:
  - Extracted some sections in reusable partials
  - Improved listings with no entries
  - Improved conditional display for some sections
  - Handled the case where the current user does not have an associated actor
  - Handled the case where the current user's class is not configured with `acts_as_federails_actor`

### Removed

- As actors' subject is a polymorphic relation, these Federails configuration options were removed: `user_class`, 
  `user_table`, `user_profile_url_method`, `user_name_field` and `user_username_field`
- `acts_as_federails_actor` is not automatically called when `Federails::Entity` concern is included in models.

### Fixed

- Client controllers: enforce authorization calls on controller actions
- Server controllers: enforce authorization calls on controller actions
- Mime types: Don't consider "application/json" as "application/ld+json"

## [0.2.0] 2024-10-13 - Sign messages, handle signed messages and remote following

### Added

- Actors now automatically generate RSA keypairs as required, and public keys are stored for remote actors.
- Added support for remote following in webfinger responses and client UI
- Outgoing activities are signed using the actor's RSA key.

## [0.1.0] 2024-09-04

As we're still in early development, don't forget to check the readme and possible configuration in `lib/federails/configuration.rb`.
As always, feedback and propositions are welcome.

### Changed

- Actors subject is now polymorphic
- Some client and server routes can be made optional

### Added

- [Pundit](https://github.com/varvet/pundit/) is now used to validate access to actions

#### Project

- Add MIT license
- Configure Gitlab CI

#### Gems

- Add Rubocop and plugins
- Add and configure RSpec
- Add and configure FactoryBot
- Add JSON-LD and JSON-LD-Preloaded

#### Dummy app

- Add and configure Devise
- Create dummy page and layout
- Create seeds

### Fixed

A lot of small fixes were made in different areas of the library.

## [0.0.1]

Creation of an empty engine
