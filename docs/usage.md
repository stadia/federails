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

### Generate configuration files

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

Object-like dependencies such as the logger should be configured in the initializer rather than YAML:

```rb
Federails.configure do |config|
  config.logger = Rails.logger
end
```

If no logger is injected, Federails falls back to Ruby's standard `Logger`.

For now, refer to [the source code](https://gitlab.com/experimentslabs/federails/-/blob/main/lib/federails/configuration.rb) 
for the full list of options.

### Copy the migrations

```sh
bundle exec rails federails:install:migrations
```

Review the changes and apply them.

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
/federation/published/:publishable_type/:id(.:format)
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
## Federails client

To get started, you can use the Federails client: routes and views to list actors, follow them, list activities, etc...

To enable the routes, set the `config.client_routes_path` to something so they can be mounted in your application.

Doing so may break some links in your layout when rendering the client views: you will need to prefix all calls to
your app's url helpers with `main_app`:

```html.erb
<%= link_to 'Users', main_app.users_url %>
```

You can override the views like with any other engine. We provide a rake task to copy them all so you can easily
override what you want:

```sh
rails generate federails:copy_client_views
```

### Disabling/not using the client

To disable the client, set `client_routes_path` to `nil`.

Disabling the client will break some of the Federails features, as Federails _needs_ some of the client routes to
generate URLS. You will need provide the routes yourself:

#### Remote following

By default, remote follow requests (where you press a follow button on another server and get redirected home to
complete the follow) will use the built-in client paths. If you're not using the client, or want to provide your own
user interface, you can set the path like this, assuming that `new_follow_url` is a valid route in your app. A `uri`
query parameter template will be automatically appended, you don't need to specify that.

```rb
Federails.configure do |config|
  config.remote_follow_url_method = :new_follow_url
end
```

This _GET_ route _should_ render a page allowing to follow the actor passed as `uri` parameter.

In the client (`app/controllers/federails/client/followings_controller.rb#new`), we use a page that allows signed-in
actor to find another actor and follow it. In the Federails client implementation, we fetch the actor, save it locally
and redirect to a page that displays it, with the "Follow" button, but you can do whatever you want, as long as the user
has ability to follow the actor in the end.


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

  on_federails_delete_requested -> { logger.info { 'Deletion requested' } }
end
```

For options, pre-requisites, etc..., refer to the documentation of `Federails::DataEntity.acts_as_federails_data`.

You can check the "Examples" for implementation samples 

You also can check the `Post` and `Comment` models from the `dummy` app (in source code: `spec/dummy`): they are both 
configured to handle Note and transform them as Post/Comment.

### Destroying entities

`DataEntity` concern uses the `after_destroy` hook to send `Delete` activities to the Fediverse. 

Incoming `Delete` activities will trigger the custom `on_federails_delete_requested` hook, and **you'll need to implement
the behavior yourself**.

### Support for soft-delete

If your model supports soft-delete, you can pass the `soft_deleted_method` and `soft_delete_date_method` parameters to
`acts_as_federails_data`. If you do so, requests made to fetch a soft-deleted entity will result into a nice `Tombstone`
ActivityPub object and a 410 _gone_ status, instead of a 404 error.

You also will need to call `create_federails_activity 'Delete'` in your soft-deletion process.

```rb
# Assume soft-deletion is made by filling `deleted_at` attribute
class Note < ApplicationRecord
  include Federails::DataEntity

  acts_as_federails_data handles: 'Note',
                         #...
                         soft_deleted_method: :deleted?,
                         soft_delete_date_method: :deleted_at

  on_federails_delete_requested :soft_delete!
  
  def deleted?
    deleted_at.present?
  end

  def soft_delete!
    update! deleted_at: Time.current
    
    # Manually create the delete activity for locally-created entities only
    create_federails_activity 'Delete' if local_federails_entity?
  end
end
```

## Using the Federails client

Federails comes with a client, enabled by default, that provides basic views to display and interact with Federails data,
accessible on `/app` by default (changeable with the configuration option `client_routes_path`)

## Inbox activity handlers

Federails registers built-in inbox handlers for the following ActivityPub activities:

- `Follow` / `Accept` / `Reject` / `Delete`
- `Like` / `Undo Like`
- `Announce` / `Undo Announce`
- `Block` / `Undo Block`

For `Like` and `Announce`, Federails routes the activity to callback points on `Federails::DataEntity`.
The gem provides the callback names; applications register their own methods on models that include `Federails::DataEntity`.

Register callbacks on the model that includes `Federails::DataEntity`:

```rb
# app/models/post.rb
class Post < ApplicationRecord
  include Federails::DataEntity

  on_federails_like_received :handle_federails_like!
  on_federails_undo_like_received :handle_federails_undo_like!
  on_federails_announce_received :handle_federails_announce!
  on_federails_undo_announce_received :handle_federails_undo_announce!

  def handle_federails_like!(actor_url)
    # Custom Like behavior for this entity
    true
  end

  def handle_federails_undo_like!(actor_url)
    # Custom Undo Like behavior for this entity
    true
  end

  def handle_federails_announce!(actor_url)
    # Custom Announce behavior for this entity
    true
  end

  def handle_federails_undo_announce!(actor_url)
    # Custom Undo Announce behavior for this entity
    true
  end
end
```

The built-in handlers resolve the target object and call:

- `object.run_callbacks :on_federails_like_received`
- `object.run_callbacks :on_federails_undo_like_received`
- `object.run_callbacks :on_federails_announce_received`
- `object.run_callbacks :on_federails_undo_announce_received`

Registered callback methods receive the activity actor as their argument.

The application is responsible for deciding how to:

- persist the activity
- enforce actor/object validation rules
- update app models
- implement undo semantics

If it's a good starting point, it might be disabled once you made your own integration by setting `client_routes_path`
to a `nil` value.

If you want to override the client's views, copy them in your application:

```sh
rails generate federails:copy_client_views
```
