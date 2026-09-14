json.links [
  {
    rel:  'http://nodeinfo.diaspora.software/ns/schema/2.0',
    href: show_node_info_url,
  },
  {
    rel:  'https://www.w3.org/ns/activitystreams#Application',
    href: Fedipub::Actor.application_actor.federated_url,
  },
]
