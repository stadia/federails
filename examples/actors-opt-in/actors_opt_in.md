# Actors creation: opt-in

Goal: only create actors based on a condition on the model (e.g.: opt-in flag, reputation, role, etc...):
maybe you want to create actors, but not for every one of the associated entities.

Let's say we have some users and only the community managers can be actors.

```rb
# app/models/users.rb

class User < ApplicationRecord
  include Federails::ActorEntity

  acts_as_federails_actor username_field: :username,
                          #...other configuration
                          auto_create_actors: false

  after_create :create_federails_actor, if: :create_federails_actor?
  after_update :create_or_destroy_federails_actor!

  private

  def create_federails_actor?
    role == :community_manager && role_previously_was != :community_manager
  end

  # Creates the actor or destroys it, depending on the condition
  def create_or_destroy_federails_actor!
    create_federails_actor if create_federails_actor?
    actor.destroy! if role != :community_manager && role_previously_was == :community_manager && self.federails_actor.present?
  end
end
```
