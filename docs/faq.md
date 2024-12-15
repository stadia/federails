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
