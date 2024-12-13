---
title: Code reference
version: '*'
---

{% assign root_namespace = site.namespaces | where: "version", page.version | first %}

# Federails reference

{% include reference/namespace.md label=false namespace=root_namespace %}
