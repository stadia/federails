# ActivityPub MUST Requirements Implementation Design

Date: 2026-03-09
Status: In progress (implementation completed on feature branch, PR opened)

## Scope

Implement 7 missing MUST requirements from the W3C ActivityPub specification.
Each item is an independent change with its own commit.

---

## 1. Inbox De-duplication

**Spec**: Section 5.2 - MUST de-duplicate activities in inbox.

**Design**: Add `federated_url` column to `federails_activities` table (unique index). On inbox POST, check `payload['id']` against existing activities. Return `200 OK` if already processed (idempotent). Consistent with `federated_url` pattern used in Actor, Following, and host app entities.

**Files**:
- New migration: `add_federated_url_to_federails_activities`
- `app/models/federails/activity.rb` - add validation
- `app/controllers/federails/server/activities_controller.rb` - add duplicate check in `create`

## 2. Exclude Self from Delivery

**Spec**: Section 7.1 - MUST exclude sending actor from recipients.

**Design**: In `Notifier#inboxes_for`, filter out the activity's own actor inbox URL from the final list.

**Files**:
- `lib/fediverse/notifier.rb` - filter in `inboxes_for`

## 3. Collection Recursion Depth Limit

**Spec**: Section 7.1 - MUST limit indirection layers through collections.

**Design**: Add `max_pages` parameter to `Collection#fetch` (default: 100). Add `max_depth` parameter to `Notifier#collection_to_actors` for nested collection indirection (default: 3).

**Files**:
- `lib/fediverse/collection.rb` - add `max_pages` limit
- `lib/fediverse/notifier.rb` - add `max_depth` for collection indirection

## 4. bto/bcc/audience Support

**Spec**: Section 7.1 - MUST deliver to bto/bcc/audience. MUST strip bto/bcc before delivery.

**Design**:
- Add `bto`, `bcc`, `audience` serialized fields to Activity model (migration)
- `Notifier#inboxes_for` collects from all 5 addressing fields
- Activity Jbuilder view strips `bto`/`bcc` from output (never sent to remote)
- `audience` is included in rendered output

**Files**:
- New migration: `add_bto_bcc_audience_to_federails_activities`
- `app/models/federails/activity.rb` - serialize new fields
- `lib/fediverse/notifier.rb` - use all 5 fields
- `app/views/federails/server/activities/_activity.activitypub.jbuilder` - add audience, exclude bto/bcc

## 5. Inbox Forwarding

**Spec**: Section 7.1.2 - MUST forward activity when all conditions are met:
1. First time seeing activity (de-duplication from #1)
2. `to`/`cc`/`audience` contains a collection owned by this server
3. `inReplyTo`/`object`/`target`/`tag` references an object owned by this server

**Design**: After successful inbox dispatch, check forwarding conditions. If met, re-deliver activity to the referenced collection's members (excluding original sender). Uses `Federails::Utils::Host.local_url?` to check ownership.

**Files**:
- `lib/fediverse/inbox.rb` - add `maybe_forward` logic
- `lib/fediverse/notifier.rb` - add `forward_activity` method for re-delivery

## 6. Update Origin Verification

**Spec**: Section 7.3 - MUST verify Update is authorized, minimum same-origin check.

**Design**: In inbox dispatch, before handling Update activities, compare the origin (host) of `activity['actor']` with the origin of the object being updated. Reject if different origin. Check applies to the object's `id` field.

**Files**:
- `lib/fediverse/inbox.rb` - add origin verification before Update dispatch

## 7. Reject Activity Handling

**Spec**: Section 7.7 - MUST NOT add to Following on Reject.

**Design**: Register `Reject + Follow` handler in Inbox. On receiving Reject, find and destroy the pending Following record (if any). This ensures the actor is never added to Following.

**Files**:
- `lib/fediverse/inbox.rb` - add `handle_reject_follow_request` + register handler

---

## Implementation Record (2026-03-09)

### Branches and PR
- Working branch: `feature/activitypub-must-requirements`
- Base branch: `main`
- PR: opened from `feature/activitypub-must-requirements` to `main`

### Implementation commits
- `df015be` — inbox de-duplication by `federated_url`
- `2f93e8d` — `bto`/`bcc`/`audience` model + rendering support
- `bebf766` — notifier recipient expansion + collection recursion/page limits
- `9cfa470` — inbox MUST behavior bundle (`Delete` idempotency recording, `Update` same-origin check, `Reject+Follow`, forwarding hooks, duplicate HTTP handling)
- `1ff8ee9` — Ruby 4 / Rails 8.1 test environment compatibility (`ostruct` dependency, non-mutating FactoryBot path assignment)

### Main branch inclusion at record time
- Included in `main`: `df015be`, `2f93e8d`, `bebf766`, and compatibility fix (`7c29237`, cherry-picked from `1ff8ee9`)
- Remaining in PR path: `9cfa470`

### Verification
- Feature branch verification run: `bundle exec rspec` => `513 examples, 0 failures`
- Main branch verification run after cherry-pick: `bundle exec rspec` => `503 examples, 0 failures`
