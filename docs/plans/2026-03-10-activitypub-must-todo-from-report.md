# ActivityPub MUST TODO From `report.md`

Date: 2026-03-10
Branch: `main`
Commit audited: `637d24d`
Source checklist: `report.md`

## Purpose

This document extracts the `MUST` and `MUST NOT` items from `report.md` and reduces them to an implementation TODO list.

Important distinction:

- not every `MUST` in `report.md` is an active TODO
- some are already implemented on `main`
- some are only relevant if Federails chooses to implement optional features such as shared inboxes, likes, shares, or client-to-server outbox posting

This document therefore focuses on:

1. definite MUST TODOs
2. scope-dependent MUST TODOs
3. MUST items that appear already satisfied and therefore do not need immediate implementation work

## Definite MUST TODOs

These are the `MUST` or `MUST NOT` items from `report.md` that still look unimplemented or not clearly enforced in code.

### 1. Expose inbox as an actual OrderedCollection resource

RFC items:

- `5.2` Inbox `MUST` be an `OrderedCollection`

Current state:

- actor objects expose an `inbox` URL
- inbox accepts `POST`
- there is no `GET /inbox` route and no inbox collection representation

Current decision:

- do not implement `GET /federation/actors/:id/inbox`

Why this is not being scheduled now:

- Federails is currently being treated as a server-to-server focused implementation
- `POST /inbox` is the meaningful interoperable surface in current scope
- exposing inbox retrieval introduces policy and privacy questions that do not fit the current scope

Follow-up implication:

- this remains an RFC gap relative to a strict reading of `5.2`
- but it is intentionally out of scope for the next implementation batch

### 2. Enforce inbound server-to-server request media type

RFC items:

- `7` POST requests to inbox `MUST` use `application/ld+json; profile="https://www.w3.org/ns/activitystreams"`

Current state:

- outbound requests are correctly generated with the ActivityPub media type
- request specs for inbox use plain `application/json`
- `ActivitiesController#create` does not visibly enforce ActivityPub media types

Why this is a TODO:

- the implementation currently accepts inbox POSTs without clearly enforcing the required ActivityPub content type

Likely work:

- reject unsupported `Content-Type` on inbox POST
- add request specs for accepted and rejected media types

### 3. Require ActivityPub retrieval with the proper Accept semantics, or document fallback behavior explicitly

RFC items:

- `3.2` clients `MUST` specify the ActivityPub `Accept` header to retrieve the activity

Current state:

- all federation request specs send ActivityPub `Accept`
- the server happily renders ActivityPub for those requests
- the codebase does not clearly enforce different behavior when the header is absent or wrong

Why this is a TODO:

- if the project intends strict RFC behavior for federated retrieval, this should be enforced or explicitly documented as permissive fallback behavior

Likely work:

- decide policy for missing/wrong `Accept`
- add tests for non-ActivityPub `Accept` on federation endpoints

## Scope-Dependent MUST TODOs

These are real `MUST` items in `report.md`, but they only become active implementation work if the related feature is in scope.

### 4. Shared inbox read semantics

RFC items:

- `4.1` shared inbox `MUST NOT` expose non-public objects if shared inbox is implemented

Current state:

- no local shared inbox endpoint exists

Interpretation:

- this is not an active implementation bug yet
- it becomes a MUST TODO only if Federails adds shared inbox support

### 5. Shared inbox fallback delivery

RFC items:

- `7.1.3` origin servers using shared inbox delivery `MUST` still deliver to non-shared-inbox recipients that would otherwise miss the activity

Current state:

- no shared inbox delivery optimization exists

Interpretation:

- not an active bug today
- becomes mandatory once shared inbox delivery is implemented

### 6. Add/Remove delivery target requirements

RFC items:

- `7` delivery for `Add` and `Remove` `MUST` include `target`

Current state:

- Federails does not implement first-class `Add` / `Remove` delivery flows

Interpretation:

- not an active defect in currently supported flows
- becomes mandatory if `Add` / `Remove` support is added

### 7. liked / likes / shares collection shape

RFC items:

- `5.5` if actor `liked` collection exists, it `MUST` be a `Collection` or `OrderedCollection`
- `5.7` if object `likes` collection exists, it `MUST` be a `Collection` or `OrderedCollection`
- `5.8` if object `shares` collection exists, it `MUST` be a `Collection` or `OrderedCollection`

Current state:

- Federails does not currently implement liked/likes/shares collection support

Interpretation:

- these are not active TODOs unless those features are added

## MUST Items That Appear Already Satisfied

These `MUST` / `MUST NOT` items from `report.md` appear already covered by current code and tests, so they should not be treated as new TODOs.

### Implemented MUSTs

- object and activity retrieval returns ActivityPub representation for federation endpoints
- actor objects include `inbox` and `outbox`
- followers and following collections are `OrderedCollection`
- collections are rendered in reverse chronological order via `order(created_at: :desc)`
- inbox de-duplication by activity `id`
- delivery dereferences collections
- collection indirection depth is limited
- final recipient list is de-duplicated
- sender is excluded from recipients
- public collection is not directly delivered to
- inbox forwarding is implemented
- inbox forwarding only uses original `to` / `cc` / `audience`
- `Update` same-origin authorization check is implemented
- `Reject(Follow)` does not add to following and is now limited to pending requests

Primary evidence:

- `lib/fediverse/inbox.rb`
- `lib/fediverse/notifier.rb`
- `lib/fediverse/collection.rb`
- `app/views/federails/server/actors/followers.activitypub.jbuilder`
- `app/views/federails/server/actors/following.activitypub.jbuilder`
- `app/views/federails/server/activities/outbox.activitypub.jbuilder`
- `spec/lib/fediverse/inbox_spec.rb`
- `spec/lib/fediverse/notifier_spec.rb`
- `spec/lib/fediverse/collection_spec.rb`
- `spec/requests/federation/actors_spec.rb`
- `spec/requests/federation/activities_spec.rb`

## Priority Recommendation

If the goal is to keep closing real `MUST` gaps from `report.md`, the next work should be:

1. Enforce the required ActivityPub `Content-Type` on inbox POST.
2. Decide whether federation endpoints should strictly require the ActivityPub `Accept` header, and implement/tests accordingly.
3. Revisit strict RFC gaps that are currently out of scope, including `GET inbox`, only if project scope expands beyond the current server-to-server focus.

After those, the next cluster is shared inbox support, but that is best handled as a dedicated feature because it introduces a new family of conditional MUSTs.

## Bottom Line

Using `report.md` as the source of truth, the number of active MUST TODOs is small.

The clearest remaining MUST work on `main` is:

- stricter media-type enforcement for server-to-server requests

Most of the other `MUST` rows in `report.md` are either already implemented, intentionally out of scope, or only become actionable if Federails expands scope into shared inboxes, Add/Remove, or likes/shares features.
