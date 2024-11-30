---
title: 'Data entity: Simple example'
---

# Data entity: simple example

Goal: Publish local `Message`s as federated _Note_ and convert incoming _Notes_ as local Post.

Configuration:
- `User` model, configured with `acts_as_federails_actor`
- `Messages` model:
  - messages can have answers (`parent` relation)
  - messages belongs to a `User`
  - doing `message.user.federails_actor` returns the actor

## Updating the "messages" table/model

First of all, as we are going to store data from the Fediverse, the posts should belong to an actor and have a 
`federated_url`.

We want to keep the relation to `User` (even if it's not mandatory, as we can use the Actor instead), so the relation can be nullable:

```rb
# db/migration/xxxx_add_federation_attributes_to_messages.rb

class AddFederationAttributesToMessages < ActiveRecord::Migration[7.1]
  def change
    change_column_null :messages, :user_id, true                              # Users are now optional
    add_column :messages, :federated_url, :string, null: true, default: nil   # Required
    add_reference :messages, :federails_actor, null: true, foreign_key: true  # Required
  end
end
```

```rb
# app/models/message.rb

class Message < ApplicationRecord
  include Federails::DataEntity
  acts_as_federails_data actor_entity_method: :user

  validates :content, presence: true, allow_blank: false

  belongs_to :user, optional: true # Change here 
  belongs_to :parent, optional: true, class_name: 'Comment', inverse_of: :answers
  has_many :answers, class_name: 'Comment', foreign_key: :parent_id  
   
  # Transforms the instance to a valid ActivityPub object   
  # @return [Hash]
  def to_activitypub_object
    Federails::DataTransformer::Note.to_federation self,
                                                   content:   content,
                                                   inReplyTo: parent?.federated_url
  end
end
```

With this configuration:
- GET requests to  `/federation/published/messages/:id` will return the Message as a Note. This URL will also be used as
  `federated_url` for local content
- When creating a new Message, a Fediverse "Create" activity for a Note will be created
