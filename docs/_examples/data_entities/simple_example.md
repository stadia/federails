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
  acts_as_federails_data handles: 'Note',
                         actor_entity_method: :user

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

  # Takes a Note hash and returns the attributes for a valid Message
  #
  # @param hash [Hash] 
  #
  # @return [Hash] Valid Hash 
  def self.from_activitypub_object(hash)
    # Gets the timestamps values with a helper
    attrs = Federails::Utils::Object.timestamp_attributes(hash)
                                    # Complete attributes
                                    .merge federated_url: hash['id'],
                                           content:       hash['content']

    # Find the parent if message is an answer
    parent = Federails::Utils::Object.find_or_create! hash['inReplyTo'] if hash['inReplyTo'].present? 
    attrs[:parent] = parent if parent

    attrs
  end
end
```

With this configuration:
- GET requests to  `/federation/published/messages/:id` will return the Message as a Note. This URL will also be used as
  `federated_url` for local content
- When creating a new Message, a Fediverse "Create" activity for a Note will be created
- When receiving a new Note from the Fediverse, a Message will be created (with its parent if it's an answer to another message)
- When updating an existing Message, a Fediverse "Update" activity for the Note will be created
- When receiving an updated Note from the Fediverse, corresponding Message will be updated (or created if missing)
