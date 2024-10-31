# Actors creation: opt-in

Goal: only create actors based on a condition on the model (e.g.: opt-in flag, reputation, role, etc...):
maybe you want to create actors, but not for every one of the associated entities.

Let's say we have some users and only the community managers can be actors.

```rb
# app/models/users.rb

class User < ApplicationRecord
  include Federails::Entity

  acts_as_federails_actor username_field: :username,
                          #...other configuration
                          auto_create_actors: false

  after_create :create_actor, if: :should_create_actor?
  after_update :create_or_destroy_actor!
  
  private

  def should_create_actor?
    role == :community_manager && role_previously_was != :community_manager
  end

  # Creates the actor or destroys it, depending on the condition
  def create_or_destroy_actor!
    create_actor if should_create_actor?
    actor.destroy! if role != :community_manager && role_previously_was == :community_manager && self.actor.present?
  end
end
```
