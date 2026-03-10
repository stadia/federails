# ActivityPub Coverage Audit

Date: 2026-03-10
Branch: `main`
Commit audited: `637d24d`

## Scope

This document summarizes how much of the ActivityPub protocol is currently implemented in Federails, based on:

- current `main` branch code
- existing project docs
- request/lib/acceptance specs
- full test suite status on `main`

This is not a clause-by-clause certification of the W3C spec. It is a practical implementation audit of what is clearly supported today and what still appears to need implementation.

## Verification Snapshot

- Full suite run on `main`: `mise exec -- bundle exec rspec`
- Result: `523 examples, 0 failures`

## What Is Clearly Implemented

### 1. Discovery and server metadata

Implemented and tested:

- WebFinger endpoint
- host-meta endpoint
- NodeInfo endpoint
- actor self-link and HTML profile link in WebFinger
- remote-follow subscribe template in WebFinger
- NodeInfo usage counts and configurable metadata

Evidence:

- `app/controllers/federails/server/web_finger_controller.rb`
- `app/views/federails/server/web_finger/find.jrd.jbuilder`
- `app/views/federails/server/nodeinfo/show.nodeinfo.jbuilder`
- `spec/requests/web_finger_spec.rb`
- `spec/requests/nodeinfo_spec.rb`
- `spec/acceptance/federails/server/web_finger_controller_spec.rb`
- `spec/acceptance/federails/server/nodeinfo_controller_spec.rb`

### 2. Actor representation and fetchable server objects

Implemented and tested:

- actor object rendering
- ActivityStreams and security contexts
- public key exposure
- actor `inbox`, `outbox`, `followers`, `following`
- tombstoned actor responses (`410 Gone` + `Tombstone`)
- published object retrieval for `DataEntity`
- activity retrieval
- outbox retrieval

Evidence:

- `app/views/federails/server/actors/_actor.activitypub.jbuilder`
- `app/views/federails/server/actors/followers.activitypub.jbuilder`
- `app/views/federails/server/actors/following.activitypub.jbuilder`
- `app/views/federails/server/activities/show.activitypub.jbuilder`
- `app/views/federails/server/activities/outbox.activitypub.jbuilder`
- `app/views/federails/server/published/_publishable.activitypub.jbuilder`
- `spec/requests/federation/actors_spec.rb`
- `spec/requests/federation/activities_spec.rb`
- `spec/requests/federation/published_controller_spec.rb`

### 3. Follow lifecycle

Implemented and tested:

- outbound `Follow` activity creation
- inbound `Follow` handling
- `Accept(Follow)`
- `Reject(Follow)`
- `Undo(Follow)`
- following/followers collection updates
- local callback hooks on follow and follow acceptance

Evidence:

- `app/models/federails/following.rb`
- `lib/fediverse/inbox.rb`
- `spec/models/federails/following_spec.rb`
- `spec/lib/fediverse/inbox_spec.rb`
- `spec/requests/app/followings_spec.rb`

### 4. Inbox processing core

Implemented and tested:

- inbox POST endpoint
- JSON parsing and JSON-LD compaction fallback
- dispatch table for handlers
- de-duplication by incoming activity `id`
- duplicate requests return `200 OK`
- `Update` same-origin verification
- `Delete` and `Undo(Delete)` handling
- forwarding of qualifying activities to local followers collections
- reject handling limited to pending follow requests

Evidence:

- `app/controllers/federails/server/activities_controller.rb`
- `lib/fediverse/inbox.rb`
- `spec/lib/fediverse/inbox_spec.rb`
- `spec/acceptance/federails/server/activities_controller_spec.rb`

### 5. Delivery and addressing

Implemented and tested:

- outbound inbox delivery for local actors
- HTTP Signature generation for outgoing requests
- recipient expansion from actors and collections
- self-recipient exclusion
- collection recursion depth limit
- collection page fetch limit
- `to`, `cc`, `bto`, `bcc`, `audience` support
- stripping `bto`/`bcc` from delivered activity serialization
- forwarding deliveries signed as the local collection owner

Evidence:

- `lib/fediverse/notifier.rb`
- `lib/fediverse/signature.rb`
- `lib/fediverse/collection.rb`
- `app/models/federails/activity.rb`
- `app/views/federails/server/activities/_activity.activitypub.jbuilder`
- `spec/lib/fediverse/notifier_spec.rb`
- `spec/lib/fediverse/signature_spec.rb`
- `spec/lib/fediverse/collection_spec.rb`
- `spec/views/federails/server/activities/show_jbuilder_spec.rb`

### 6. Generic inbound object support for app-defined models

Implemented and tested:

- pluggable `Create` and `Update` handling for configured `DataEntity` classes
- dereferencing remote Note objects
- creating local records from inbound federated objects
- recursive parent fetch for replies
- soft-delete / tombstone support for published entities

Evidence:

- `app/models/concerns/federails/data_entity.rb`
- `lib/federails/utils/object.rb`
- `spec/dummy/spec/requests/federation/inbox_note_for_post_spec.rb`
- `spec/dummy/spec/requests/federation/inbox_note_for_comment_spec.rb`
- `spec/acceptance/federails/server/published_controller_spec.rb`

## Current Coverage Assessment

At a practical level, Federails already implements the core server-to-server ActivityPub surface needed for:

- actor discovery
- actor fetch
- object fetch
- outbox fetch
- followers/following fetch
- follow / accept / reject / undo flow
- signed outbound delivery
- inbox reception and dispatch
- generic inbound Create/Update for configured object types
- delete / undelete handling
- a recent bundle of MUST-level inbox and delivery compliance fixes

In short: the project has meaningful server-to-server ActivityPub support, not just discovery stubs.

## Things That Still Look Missing or Incomplete

These items are extracted from the current codebase by looking for missing routes, missing handlers, missing persistence fields, and missing tests. They are good candidates for future implementation work.

### 1. Inbound HTTP Signature verification

Current state:

- outgoing signatures are implemented
- inbound inbox authentication is not visibly enforced in `ActivitiesController#create`
- `Fediverse::Signature.verify` exists, but is only exercised in unit tests and is not wired into inbox request handling

Why it matters:

- this is a major interoperability and security gap
- current inbox acceptance relies on payload shape and object dereferencing, not sender authentication

Relevant files:

- `lib/fediverse/signature.rb`
- `app/controllers/federails/server/activities_controller.rb`

### 2. Shared inbox support

Current state:

- remote actor payloads in fixtures include `endpoints.sharedInbox`
- local actor rendering does not expose `endpoints.sharedInbox`
- outbound delivery targets actor inboxes individually
- there is no shared inbox route on the local server

Why it matters:

- shared inbox delivery is a common interoperability optimization
- some server implementations expect it for efficient fan-out

Relevant evidence:

- fixtures under `spec/fixtures/vcr_cassettes/**` include `sharedInbox`
- no `sharedInbox` implementation is present in `app/`, `lib/`, or routes

### 3. Broader activity type support

Current state:

- built-in handlers exist for `Follow`, `Accept(Follow)`, `Reject(Follow)`, `Undo(Follow)`, `Delete`, `Undo(Delete)`
- `DataEntity` adds generic `Create` and `Update` handling for configured object types
- there is no built-in support for common activities such as `Like`, `Announce`, `Add`, `Remove`, `Block`, or `Move`

Why it matters:

- these are important for broader Fediverse behavior even if not all are MUST for every server profile
- current functionality is strong for follows and notes, but narrow outside that slice

Relevant files:

- `lib/fediverse/inbox.rb`
- `app/models/concerns/federails/data_entity.rb`

### 4. Client-to-server outbox posting

Current state:

- outbox is fetchable via GET
- there is no server endpoint for POSTing to outbox
- the library appears focused on server-to-server federation plus host-app initiated publishing

Why it matters:

- if Federails wants fuller ActivityPub profile coverage, client-to-server posting is still absent
- if server-to-server only is the intended scope, this should be explicitly documented as out of scope

Relevant evidence:

- routes expose `GET /outbox` but no `POST /outbox`
- no controller action exists for outbox creation

### 5. Shared, explicit spec coverage reporting

Current state:

- `specs.yaml` contains the RFC structure
- the codebase does not currently publish a maintained matrix of “implemented / partial / missing” by spec section

Why it matters:

- protocol progress is currently discoverable only by reading code and tests
- contributors need a maintained target list

## Recommended Next Implementation List

Priority order:

1. Add inbound HTTP Signature verification for inbox POSTs, with clear failure semantics and tests.
2. Add shared inbox support:
   - expose `endpoints.sharedInbox` on local actors
   - add a shared inbox route
   - prefer shared inbox delivery for remote actors when available
3. Decide and document project scope for client-to-server support:
   - either explicitly declare it out of scope
   - or implement `POST /outbox`
4. Add first-class support for more activity types, starting with `Like` and `Announce`.
5. Maintain an RFC coverage matrix derived from `specs.yaml` and current tests.

## Bottom Line

Federails is no longer in a state where ActivityPub support is vague. As of `637d24d`, the core server-to-server pieces are implemented and passing tests, including the recent MUST-compliance work around inbox de-duplication, addressing, recursion limits, forwarding, update verification, and reject handling.

The main remaining gaps are not in the already-planned 7 MUST items. They are the next layer of protocol maturity:

- authenticating inbound deliveries
- supporting shared inboxes
- broadening supported activity types
- clarifying whether client-to-server ActivityPub is in or out of scope
