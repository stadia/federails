---
title: Usage
nav_order: 10
---

# Installation

Add this line to your application's Gemfile:

```ruby
gem "federails"
```

And then execute:

```bash
$ bundle
```

## Configuration

Generate configuration files:

```sh
bundle exec rails generate federails:install
```

It creates an initializer and a configuration file:
- `config/initializers/federails.rb`
- `config/federails.yml`

By default, Federails is configured using `config_from` method, that loads the appropriate YAML file, but you may want
to configure it differently:

```rb
# config/initializers/federails.rb
Federails.configure do |config|
  config.host = 'localhost'
  # ...
end
```

For now, refer to [the source code](https://gitlab.com/experimentslabs/federails/-/blob/main/lib/federails/configuration.rb) 
for the full list of options.

## Routes

Mount the engine on `/`: routes to `/.well-known/*` and `/nodeinfo/*` must be at the root of the site.
Federails routes are then available under the configured path (`routes_path`):

```rb
# config/routes.rb
mount Federails::Engine => '/'
```

With `routes_path = 'federation'`, routes will be:

```txt
/.well-known/webfinger(.:format)
/.well-known/host-meta(.:format)
/.well-known/nodeinfo(.:format)
/nodeinfo/2.0(.:format)
/federation/actors/:id/followers(.:format)
/federation/actors/:id/following(.:format)
/federation/actors/:actor_id/outbox(.:format)
/federation/actors/:actor_id/inbox(.:format)
/federation/actors/:actor_id/activities/:id(.:format)
/federation/actors/:actor_id/followings/:id(.:format)
/federation/actors/:actor_id/notes/:id(.:format)
/federation/actors/:id(.:format)
...
```

Some routes can be disabled in configuration if you don't want to expose particular features:

```rb
Federails.configure do |config|
  # Disable routing for .well-known and nodeinfo
  config.enable_discovery = false

  # Disable web client UI routes
  config.client_routes_path = nil
end
```

### Remote following

By default, remote follow requests (where you press a follow button on another server and get redirected home to complete the follow)
will use the built-in client paths. If you're not using the client, or want to provide your own user interface, you can set the path like this, assuming that `new_follow_url` is a valid route in your app. A `uri` query parameter template will be automatically appended, you don't need to specify that.

```rb
Federails.configure do |config|
  config.remote_follow_url_method = :new_follow_url
end
```

## Migrations

Copy the migrations:

```sh
bundle exec rails federails:install:migrations
```

## User model

In the ActivityPub world, we refer to _actors_ to represent the thing that publishes or subscribe to _other actors_.

Federails provides a concern to include in your "user" model or whatever will publish data:

```rb
# app/models/user.rb

class User < ApplicationRecord
  # Include the concern here:
  include Federails::ActorEntity

  # Configure field names
  acts_as_federails_actor username_field: :username, name_field: :name, profile_url_method: :user_url
end
```

This concern automatically create a `Federails::Actor` after a user creation, as well as the `actor` reference. When adding it to
an existing model with existing data, you will need to generate the corresponding actors yourself in a migration.

Usage example:

```rb
actor = User.find(1).federails_actor

actor.inbox
actor.outbox
actor.followers
actor.following
#...
```

## Data models

To ease the work of publishing data to the Fediverse and saving content from it, Federails provides a concern to include
in the data models:


```rb
class Note < ApplicationRecord
  include Federails::DataEntity
  
  acts_as_federails_data
end
```

For options, pre-requisites, etc..., refer to the documentation of `Federails::DataEntity.acts_as_federails_data`.

You can check the "Examples" for implementation samples 

You also can check the `Post` and `Comment` models from the `dummy` app (in source code: `spec/dummy`): they are both 
configured to handle Note and transform them as Post/Comment. 

## Using the Federails client

Federails comes with a client, enabled by default, that provides basic views to display and interact with Federails data,
accessible on `/app` by default (changeable with the configuration option `client_routes_path`)

If it's a good starting point, it might be disabled once you made your own integration by setting `client_routes_path`
to a `nil` value.

If you want to override the client's views, copy them in your application:

```sh
rails generate federails:copy_client_views
```
