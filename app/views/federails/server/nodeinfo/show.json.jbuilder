json.version '2.0'
# FIXME: Use configuration values when created
json.software name:    Federails::Configuration.app_name,
              version: Federails::Configuration.app_version
json.protocols [
  'activitypub',
]
# FIXME: When server is in good shape: update outbounds
# http://nodeinfo.diaspora.software/ns/schema/2.0 for possible values
json.services inbound:  [],
              outbound: []
# FIXME: Don't hardcode this
json.openRegistrations true
json.usage users: {
  total:          @total,
  activeMonth:    @active_month,
  activeHalfyear: @active_halfyear,
}
json.metadata({})
