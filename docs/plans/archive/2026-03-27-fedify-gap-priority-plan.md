# Fedify Gap Priority Plan

Date: 2026-03-27
Reference project: `/Users/jeff.dean/github/fedify`
Target project: `/Users/jeff.dean/projects/federails`

## Goal

Use Fedify as the reference ActivityPub server framework and extract the next
set of implementation priorities for Federails after the recent MUST-level
server-to-server work.

This is not a "copy Fedify" plan.
It is a practical gap analysis:

- what Fedify provides as a framework
- what Federails already has
- what should be implemented next, in order

## Current Federails baseline

Based on the current code and recent planning docs, Federails already has
meaningful server-to-server coverage in these areas:

- discovery: WebFinger, host-meta, NodeInfo
- actor rendering and object fetch
- outbox fetch
- followers/following fetch
- inbox POST handling
- follow / accept / reject / undo lifecycle
- generic inbound `Create` / `Update` handling for configured `DataEntity`
- outbound delivery with draft HTTP Signature generation
- de-duplication, forwarding hooks, same-origin `Update` validation

Key local references:

- `docs/plans/2026-03-10-activitypub-coverage-audit.md`
- `app/controllers/federails/server/activities_controller.rb`
- `lib/fediverse/inbox.rb`
- `lib/fediverse/notifier.rb`
- `lib/fediverse/signature.rb`

## Fedify capabilities that matter most

The Fedify project is strongest not only at protocol primitives, but at the
framework surface around them.

Most relevant capabilities observed in Fedify:

- automatic inbound signature verification at inbox boundaries
- first-class personal inbox and shared inbox handling
- shared inbox aware outbound delivery
- queue-backed delivery with retries and permanent failure handling
- fan-out optimization for large recipient sets
- ordered delivery support for related activities
- broader activity vocabulary support
- followers collection synchronization (`FEP-8fcf`)
- newer signature/proof stack:
  - draft HTTP Signatures
  - RFC 9421 HTTP Message Signatures
  - Linked Data Signatures
  - Object Integrity Proofs
- reusable framework integration patterns and debugging CLI

Key Fedify references:

- `docs/intro.md`
- `docs/manual/inbox.md`
- `docs/manual/send.md`
- `docs/manual/actor.md`
- `docs/manual/collections.md`
- `FEDERATION.md`

## Gap summary

The main Federails gaps compared to Fedify are not basic actor fetch or follow
support anymore. They are the next-layer concerns:

1. inbound request authentication
2. shared inbox support
3. delivery reliability and scale behavior
4. breadth of activity support
5. modern interoperability features beyond minimum compliance

## Priority plan

## P0. Inbound HTTP Signature verification

### Why this is first

This is the most important security and interoperability gap.
Federails can currently generate outbound signatures, but inbound inbox POSTs
are not visibly rejected based on sender authentication before dispatch.

Fedify treats signature verification as a default inbox boundary concern.

### Scope

- verify draft-cavage HTTP Signature on inbound inbox POST
- resolve the signing actor key from the request / payload
- reject invalid or missing signatures with clear failure semantics
- keep duplicate handling and payload validation behavior intact

### Candidate files

- `app/controllers/federails/server/activities_controller.rb`
- `lib/fediverse/signature.rb`
- `lib/fediverse/request.rb`
- request / acceptance specs around inbox POST

### Done when

- unsigned inbox POST is rejected
- invalidly signed inbox POST is rejected
- valid signed inbox POST still dispatches correctly
- duplicate signed requests still return idempotent success

## P0. Shared inbox support

### Why this is second

Fedify models shared inbox as a first-class concept.
Federails currently exposes only personal inboxes and delivers actor-by-actor.
This is a real interoperability and efficiency gap.

### Scope

- expose `endpoints.sharedInbox` in local actor JSON
- add a shared inbox route
- accept inbound activities through the shared inbox
- prefer remote `sharedInbox` for delivery when available
- fall back to personal inbox when absent

### Candidate files

- `config/routes.rb`
- `app/views/federails/server/actors/_actor.activitypub.jbuilder`
- `app/controllers/federails/server/activities_controller.rb`
- `lib/fediverse/notifier.rb`
- actor / activities request specs

### Done when

- actor representation includes `endpoints.sharedInbox`
- shared inbox endpoint accepts the same valid activity classes as personal inbox
- outbound delivery coalesces same-server recipients to shared inbox where possible

## P1. Delivery reliability and ordering

### Why this is next

Federails already has asynchronous delivery via `ActiveJob`, but not the richer
delivery contract that Fedify provides for retry policy, permanent failure
handling, and per-object ordering.

This becomes important as soon as local posting volume or follower counts grow.

### Scope

- add retry strategy for failed inbox deliveries
- classify permanent failures like `404` / `410`
- add hooks for cleanup on permanent failure
- define ordering behavior for related activities:
  - `Create` -> `Update` -> `Delete`
  - `Follow` -> `Undo(Follow)`

### Candidate files

- `app/jobs/federails/notify_inbox_job.rb`
- `lib/fediverse/notifier.rb`
- `app/models/federails/activity.rb`

### Done when

- transient delivery failures are retried predictably
- permanent failures stop retrying
- related activities cannot overtake one another for the same remote server

## P1. First-class activity expansion

### Why this matters

Federails is currently strong for follows and generic object creation/update,
but narrow outside that slice.

Fedify's framework surface assumes broader activity vocabulary support.

### Recommended order

1. `Like`
2. `Announce`
3. `Block`
4. `Move`

### Scope

- define built-in handling expectations for each activity
- decide what is framework responsibility vs host app responsibility
- add persistence or hooks only where Federails can support them cleanly

### Candidate files

- `lib/fediverse/inbox.rb`
- `app/models/concerns/federails/data_entity.rb`
- relevant models and request specs

### Done when

- each supported activity has explicit dispatch behavior
- each has request / lib spec coverage
- unsupported activities are still deliberately ignored, not accidentally ignored

## P1. Followers synchronization and shared-inbox fan-out

### Why this follows shared inbox

Fedify supports followers collection synchronization (`FEP-8fcf`) to make
shared-inbox delivery to follower audiences efficient.

This should come after shared inbox support, not before it.

### Scope

- model server-grouped follower delivery
- attach followers collection digest or equivalent synchronization metadata
- reduce duplicate deliveries to the same remote server

### Candidate files

- `lib/fediverse/notifier.rb`
- followers collection rendering / helper code
- follow relationship models if extra state is needed

### Done when

- large follower fan-out does not degrade to one POST per remote follower
- behavior is covered with specs that group recipients by remote server

## P2. Modern signature and proof stack

### Why this is lower priority

This is valuable, but not the sharpest current gap.
Shared inbox and inbound verification provide more immediate value.

### Scope

- RFC 9421 HTTP Message Signatures
- actor multikey / assertion method exposure
- Object Integrity Proof verification and generation
- Linked Data Signature compatibility only if required for real-world interop

### Candidate files

- `lib/fediverse/signature.rb`
- actor rendering views
- actor key material storage / configuration

## P2. Developer and operations surface

### Why it matters

A major Fedify strength is that it feels like a framework product, not just a
library with protocol helpers.

Federails should gradually improve the surrounding operator experience too.

### Candidate areas

- protocol coverage matrix generated from current tests and `specs.yaml`
- debugging rake tasks / CLI helpers for lookup and delivery inspection
- shared test helpers for signed requests and fixture actors
- optional relay-oriented extension surface

## Recommended execution order

1. inbound HTTP Signature verification
2. shared inbox support
3. delivery retry / permanent failure / ordering
4. `Like`
5. `Announce`
6. followers synchronization
7. RFC 9421 and proof stack
8. operator tooling and coverage reporting

## Explicit non-goals for now

These may be revisited later, but should not block the priority list above:

- full client-to-server ActivityPub support
- trying to match every Fedify package feature one-for-one
- relay server support inside core Federails
- broad cryptographic redesign before shared inbox and inbound auth are solved

## Suggested next implementation tranche

The next implementation milestone should combine the first two P0 items:

1. wire inbound HTTP Signature verification into inbox POST handling
2. add shared inbox discovery and routing
3. update outbound delivery to prefer shared inboxes

This tranche gives the best immediate improvement in:

- security
- interoperability
- network efficiency
- Fedify parity on the most important server framework surface
