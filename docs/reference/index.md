---
title: Class list
version: '*'
---

{% assign root_namespace = site.namespaces | where: "version", page.version | first %}

# Fedipub class list

{% include reference/namespace.md label=false namespace=root_namespace %}
