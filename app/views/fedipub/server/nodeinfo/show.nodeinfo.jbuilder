json.version '2.0'
json.software name:    Fedipub::Configuration.app_name&.parameterize,
              version: Fedipub::Configuration.app_version
json.protocols [
  'activitypub',
]
# FIXME: When server is in good shape: update outbounds
# http://nodeinfo.diaspora.software/ns/schema/2.0 for possible values
json.services inbound:  [],
              outbound: []
json.openRegistrations Fedipub::Configuration.open_registrations
if @has_user_counts
  json.usage users: {
    total:          @total,
    activeMonth:    @active_month,
    activeHalfyear: @active_halfyear,
  }
end
json.metadata(Fedipub::Configuration.nodeinfo_metadata || {})
