---
title: Common questions
nav_order: 30
---

# Common questions

- **I override the base controller and the links breaks in my layout**

  Use `main_app.<url_helper>` for links to your application; `federails.<federails_url_helper>` for links to the Federails client.
- **I specified a custom layout and the links breaks in it**

  Use `main_app.<url_helper>` for links to your application; `federails.<federails_url_helper>` for links to the Federails client.
- **I specified a custom layout and my helpers are not available**

  You will have better results if you specify a `base_controller` from your application as Federails base controller is isolated from the main app and does not have access to its helpers.
- **I want distant actors to have an _entity_ too**

  In the _entity_ model, override the `create_federails_actor_as_local?`. Its return value will determine if the related actor is local or not.
  ```rb
  class Author < ApplicationRecord
    include Federails::ActorEntity
    #...
    
    private
  
    def create_federails_actor_as_local?
      false # All actors related to Author model are created as distant Actors 
    end
  end
  ```
- **I use FactoryBot, how can I use the Federails factories in my specs?**

  You can include the Federails factories this way in your spec helper:
  ```rb
  FactoryBot.definition_file_paths << Federails::Engine.root.join('spec', 'factories')
  FactoryBot.reload # May be optional given your setup
  ```
