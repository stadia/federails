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
-->

## [Unreleased]

### Added

- Base controller for client controllers can be specified to something different from `ActionController::Base` with the 
  `base_client_controller` option
- New generator: `federails:copy_client_views`, that copies all the client views in `app/views/federails/client` for override
- Added `auto_create_actors` option for `acts_as_federails_actor` method to disable automatic actor creation.

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
