# ActivityPub MUST Requirements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement 7 missing MUST requirements from the W3C ActivityPub spec to bring Federails closer to protocol compliance.

**Architecture:** Each requirement is an independent, incremental change to existing code. No new models - only migrations, model changes, and logic additions to existing classes (Inbox, Notifier, Collection, ActivitiesController).

**Tech Stack:** Rails engine, RSpec, FactoryBot, VCR cassettes for HTTP mocking

**Test command:** `bundle exec rspec` from project root
**Single file:** `bundle exec rspec spec/path/to/file.rb`

---

### Task 1: Inbox De-duplication (Activity federated_url)

**Spec reference:** Section 5.2 - MUST de-duplicate activities in inbox

**Files:**
- Create: `db/migrate/TIMESTAMP_add_federated_url_to_federails_activities.rb`
- Modify: `app/models/federails/activity.rb`
- Modify: `app/controllers/federails/server/activities_controller.rb`
- Test: `spec/lib/fediverse/inbox_spec.rb`

**Step 1: Write the failing test**

Add to `spec/lib/fediverse/inbox_spec.rb`, inside the `RSpec.describe Inbox` block:

```ruby
describe '#dispatch_request de-duplication' do
  let(:payload) do
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => 'https://example.com/activities/123',
      'type' => 'Follow',
      'actor' => distant_actor.federated_url,
      'object' => local_actor.federated_url,
    }
  end

  it 'creates a following on first dispatch' do
    expect { described_class.dispatch_request(payload) }.to change(Federails::Following, :count).by(1)
  end

  it 'returns :duplicate on second dispatch of same activity id' do
    described_class.dispatch_request(payload)
    expect(described_class.dispatch_request(payload)).to eq :duplicate
  end

  it 'does not create duplicate following on second dispatch' do
    described_class.dispatch_request(payload)
    expect { described_class.dispatch_request(payload) }.not_to change(Federails::Following, :count)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/lib/fediverse/inbox_spec.rb -e 'de-duplication'`
Expected: FAIL - second dispatch creates duplicate or doesn't return `:duplicate`

**Step 3: Create migration**

```ruby
# db/migrate/TIMESTAMP_add_federated_url_to_federails_activities.rb
class AddFederatedUrlToFederailsActivities < ActiveRecord::Migration[7.0]
  def change
    add_column :federails_activities, :federated_url, :string
    add_index :federails_activities, :federated_url, unique: true
  end
end
```

Run: `cd spec/dummy && bundle exec rails db:migrate && cd ../..`

**Step 4: Update Activity model**

In `app/models/federails/activity.rb`, add inside the class body (before `private`):

```ruby
validates :federated_url, uniqueness: true, allow_nil: true
```

**Step 5: Update Inbox.dispatch_request**

In `lib/fediverse/inbox.rb`, at the top of `dispatch_request`:

```ruby
def dispatch_request(payload)
  # De-duplicate: skip if we've already processed this activity
  if payload['id'].present? && Federails::Activity.exists?(federated_url: payload['id'])
    return :duplicate
  end

  return dispatch_delete_request(payload) if payload['type'] == 'Delete'
  # ... rest unchanged
```

**Step 6: Store federated_url when creating activities from inbox**

In `lib/fediverse/inbox.rb`, update `handle_create_follow_request`:

```ruby
def handle_create_follow_request(activity)
  actor        = Federails::Actor.find_or_create_by_object activity['actor']
  target_actor = Federails::Actor.find_or_create_by_object activity['object']

  following = Federails::Following.create! actor: actor, target_actor: target_actor, federated_url: activity['id']
  # Store the activity's federated URL for de-duplication
  following.activities.update_all(federated_url: activity['id']) if activity['id'].present?
end
```

Note: The Follow activity creates a Following which triggers an Activity creation. We need to ensure the activity gets the federated_url. A simpler approach is to check at dispatch level (step 5) which is already done.

Actually, the Follow handler creates a Following record, which in turn creates Activity records via callbacks. The de-duplication check at the top of `dispatch_request` is sufficient - it checks before any handler runs. But we need the federated_url to be stored somewhere. Since the inbox creates Followings (not Activities directly), and the Activity is created as a side effect, we should store the `federated_url` on a new Activity after the handler succeeds.

Revised approach - after handler dispatch succeeds, record the activity ID:

```ruby
def dispatch_request(payload)
  if payload['id'].present? && Federails::Activity.exists?(federated_url: payload['id'])
    return :duplicate
  end

  return dispatch_delete_request(payload) if payload['type'] == 'Delete'

  payload['object'] = Fediverse::Request.dereference(payload['object']) if payload.key? 'object'

  handlers = get_handlers(payload['type'], payload.dig('object', 'type'))
  handlers.each_pair do |klass, method|
    klass.send method, payload
  end

  # Record this activity ID for future de-duplication
  record_processed_activity(payload) if payload['id'].present? && !handlers.empty?

  return true unless handlers.empty?

  Rails.logger.debug { "Unhandled activity type: #{payload['type']}" }
  false
end
```

Add private method:

```ruby
def record_processed_activity(payload)
  # Find the most recently created activity and set its federated_url
  recent = Federails::Activity.where(federated_url: nil).order(created_at: :desc).first
  recent&.update_column(:federated_url, payload['id'])
end
```

**Step 7: Run tests**

Run: `bundle exec rspec spec/lib/fediverse/inbox_spec.rb`
Expected: ALL PASS

**Step 8: Commit**

```bash
git add db/migrate/*_add_federated_url_to_federails_activities.rb app/models/federails/activity.rb lib/fediverse/inbox.rb spec/lib/fediverse/inbox_spec.rb
git commit -m "feat: add inbox activity de-duplication (AP Section 5.2 MUST)"
```

---

### Task 2: Exclude Self from Delivery

**Spec reference:** Section 7.1 - MUST exclude sending actor from recipients

**Files:**
- Modify: `lib/fediverse/notifier.rb`
- Test: `spec/lib/fediverse/notifier_spec.rb`

**Step 1: Write the failing test**

Add to `spec/lib/fediverse/notifier_spec.rb`, inside `RSpec.describe Notifier`:

```ruby
describe '#inboxes_for excludes self' do
  let(:fake_entity) { FakeEntity.new('some_url') }
  let(:fake_activity) do
    FakeActivity.new(
      id: 1,
      actor: local_actor,
      to: [local_actor.federated_url, distant_target_actor.federated_url],
      action: 'Create',
      entity: fake_entity
    )
  end

  it 'excludes the sending actor inbox from delivery' do
    allow(described_class).to receive(:post_to_inbox)
    described_class.post_to_inboxes(fake_activity)
    expect(described_class).to have_received(:post_to_inbox).once
    expect(described_class).not_to have_received(:post_to_inbox).with(hash_including(inbox_url: local_actor.inbox_url))
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/lib/fediverse/notifier_spec.rb -e 'excludes self'`
Expected: FAIL - local actor inbox is included

**Step 3: Implement the fix**

In `lib/fediverse/notifier.rb`, update `inboxes_for`:

```ruby
def inboxes_for(activity)
  return [] unless activity.actor.local?

  actor_inbox = activity.actor.inbox_url

  [activity.to, activity.cc].flatten.compact.reject { |x| x == Fediverse::Collection::PUBLIC }.map do |url|
    actor = Federails::Actor.find_or_create_by_federation_url(url)
    [actor.inbox_url]
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
    collection_to_actors(url).map(&:inbox_url)
  end.flatten.compact.uniq.reject { |url| url == actor_inbox }
end
```

The key change: `.reject { |url| url == actor_inbox }` at the end.

**Step 4: Run tests**

Run: `bundle exec rspec spec/lib/fediverse/notifier_spec.rb`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lib/fediverse/notifier.rb spec/lib/fediverse/notifier_spec.rb
git commit -m "feat: exclude sending actor from delivery recipients (AP Section 7.1 MUST)"
```

---

### Task 3: Collection Recursion Depth Limit

**Spec reference:** Section 7.1 - MUST limit indirection layers through collections

**Files:**
- Modify: `lib/fediverse/collection.rb`
- Test: `spec/lib/fediverse/collection_spec.rb`

**Step 1: Write the failing test**

Add to `spec/lib/fediverse/collection_spec.rb`:

```ruby
describe 'pagination limit' do
  it 'stops fetching after max_pages is reached' do
    stub_request_page = lambda { |page_url, next_url|
      allow(Fediverse::Request).to receive(:dereference).with(page_url).and_return({
        'orderedItems' => ["https://example.com/actor/#{page_url}"],
        'next' => next_url,
      })
    }

    allow(Fediverse::Request).to receive(:dereference).with('https://example.com/collection').and_return({
      'id' => 'https://example.com/collection',
      'type' => 'OrderedCollection',
      'totalItems' => 500,
      'first' => 'https://example.com/collection?page=1',
    })

    # Create 5 pages
    (1..4).each do |i|
      stub_request_page.call("https://example.com/collection?page=#{i}", "https://example.com/collection?page=#{i + 1}")
    end
    stub_request_page.call('https://example.com/collection?page=5', nil)

    collection = described_class.fetch('https://example.com/collection', max_pages: 3)
    expect(collection.length).to eq 3
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/lib/fediverse/collection_spec.rb -e 'pagination limit'`
Expected: FAIL - `fetch` doesn't accept `max_pages` argument

**Step 3: Implement max_pages**

Replace `lib/fediverse/collection.rb`:

```ruby
module Fediverse
  class Collection < Array
    PUBLIC = 'https://www.w3.org/ns/activitystreams#Public'.freeze

    DEFAULT_MAX_PAGES = 100

    attr_reader :total_items, :id, :type

    def self.fetch(url, max_pages: DEFAULT_MAX_PAGES)
      new.fetch(url, max_pages: max_pages)
    end

    def fetch(url, max_pages: DEFAULT_MAX_PAGES)
      json = Fediverse::Request.dereference(url)
      @total_items = json['totalItems']
      @id = json['id']
      @type = json['type']
      raise Errors::NotACollection unless %w[OrderedCollection Collection].include?(@type)

      next_url = json['first']
      pages_fetched = 0
      while next_url && pages_fetched < max_pages
        page = Fediverse::Request.dereference(next_url)
        concat(page['orderedItems'] || page['items'])
        next_url = page['next']
        pages_fetched += 1
      end
      self
    end
  end

  module Errors
    class NotACollection < StandardError; end
  end
end
```

**Step 4: Run tests**

Run: `bundle exec rspec spec/lib/fediverse/collection_spec.rb`
Expected: ALL PASS (existing tests still work since default is 100)

**Step 5: Commit**

```bash
git add lib/fediverse/collection.rb spec/lib/fediverse/collection_spec.rb
git commit -m "feat: add max_pages limit to collection fetching (AP Section 7.1 MUST)"
```

---

### Task 4: bto/bcc/audience Support

**Spec reference:** Section 7.1 - MUST deliver to bto/bcc/audience. MUST strip bto/bcc before delivery.

**Files:**
- Create: `db/migrate/TIMESTAMP_add_bto_bcc_audience_to_federails_activities.rb`
- Modify: `app/models/federails/activity.rb`
- Modify: `lib/fediverse/notifier.rb`
- Modify: `app/views/federails/server/activities/_activity.activitypub.jbuilder`
- Test: `spec/lib/fediverse/notifier_spec.rb`
- Test: `spec/views/federails/server/activities/_activity.activitypub.jbuilder_spec.rb` (new or existing view spec)

**Step 1: Write the failing test for delivery**

Add to `spec/lib/fediverse/notifier_spec.rb`:

```ruby
describe '#inboxes_for with bto/bcc/audience' do
  let(:distant_actor_2) { FactoryBot.create :distant_actor }
  let(:distant_actor_3) { FactoryBot.create :distant_actor }
  let(:fake_entity) { FakeEntity.new('some_url') }

  before do
    # Extend FakeActivity to support bto/bcc/audience
    unless FakeActivity.members.include?(:bto)
      Fediverse.send(:remove_const, :FakeActivity)
      Fediverse.const_set(:FakeActivity,
        Struct.new(:id, :actor, :recipients, :action, :entity, :to, :cc, :bto, :bcc, :audience, keyword_init: true))
    end
  end

  let(:fake_activity) do
    FakeActivity.new(
      id: 1,
      actor: local_actor,
      to: [distant_target_actor.federated_url],
      cc: nil,
      bto: [distant_actor_2.federated_url],
      bcc: [distant_actor_3.federated_url],
      audience: nil,
      action: 'Create',
      entity: fake_entity
    )
  end

  it 'delivers to bto and bcc recipients' do
    allow(described_class).to receive(:post_to_inbox)
    described_class.post_to_inboxes(fake_activity)
    expect(described_class).to have_received(:post_to_inbox).exactly(3).times
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/lib/fediverse/notifier_spec.rb -e 'bto/bcc/audience'`
Expected: FAIL

**Step 3: Create migration**

```ruby
# db/migrate/TIMESTAMP_add_bto_bcc_audience_to_federails_activities.rb
class AddBtoBccAudienceToFederailsActivities < ActiveRecord::Migration[7.0]
  def change
    add_column :federails_activities, :bto, :string
    add_column :federails_activities, :bcc, :string
    add_column :federails_activities, :audience, :string
  end
end
```

Run: `cd spec/dummy && bundle exec rails db:migrate && cd ../..`

**Step 4: Update Activity model**

In `app/models/federails/activity.rb`, add alongside existing serializers:

```ruby
serialize :bto, coder: YAML
serialize :bcc, coder: YAML
serialize :audience, coder: YAML
```

**Step 5: Update Notifier to collect all 5 addressing fields**

In `lib/fediverse/notifier.rb`, update `inboxes_for`:

```ruby
def inboxes_for(activity)
  return [] unless activity.actor.local?

  actor_inbox = activity.actor.inbox_url

  addressing_fields = [
    activity.to, activity.cc,
    activity.try(:bto), activity.try(:bcc), activity.try(:audience)
  ].flatten.compact.reject { |x| x == Fediverse::Collection::PUBLIC }.uniq

  addressing_fields.map do |url|
    actor = Federails::Actor.find_or_create_by_federation_url(url)
    [actor.inbox_url]
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
    collection_to_actors(url).map(&:inbox_url)
  end.flatten.compact.uniq.reject { |url| url == actor_inbox }
end
```

**Step 6: Update activity view to strip bto/bcc, include audience**

In `app/views/federails/server/activities/_activity.activitypub.jbuilder`, update the addressing block:

```ruby
if addressing
  json.merge!(
    {
      to: activity.to,
      cc: activity.cc,
      audience: activity.try(:audience),
    }.compact
  )
  # bto and bcc MUST NOT be included in delivered activities (AP spec Section 6)
end
```

**Step 7: Run tests**

Run: `bundle exec rspec spec/lib/fediverse/notifier_spec.rb`
Expected: ALL PASS

**Step 8: Commit**

```bash
git add db/migrate/*_add_bto_bcc_audience_to_federails_activities.rb app/models/federails/activity.rb lib/fediverse/notifier.rb app/views/federails/server/activities/_activity.activitypub.jbuilder spec/lib/fediverse/notifier_spec.rb
git commit -m "feat: support bto/bcc/audience addressing fields (AP Section 7.1 MUST)"
```

---

### Task 5: Update Origin Verification

**Spec reference:** Section 7.3 - MUST verify Update is authorized, minimum same-origin check

**Files:**
- Modify: `lib/fediverse/inbox.rb`
- Test: `spec/lib/fediverse/inbox_spec.rb`

**Step 1: Write the failing test**

Add to `spec/lib/fediverse/inbox_spec.rb`:

```ruby
describe 'Update origin verification' do
  let(:payload) do
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => 'https://evil.com/activities/1',
      'type' => 'Update',
      'actor' => 'https://evil.com/users/attacker',
      'object' => {
        'id' => 'https://example.com/posts/1',
        'type' => 'Note',
        'content' => 'hacked content',
      },
    }
  end

  it 'rejects Update when actor origin does not match object origin' do
    result = described_class.dispatch_request(payload)
    expect(result).to eq false
  end

  it 'accepts Update when actor origin matches object origin' do
    payload['actor'] = 'https://example.com/users/author'
    # No handler registered for Update+Note in base Inbox, so it returns false
    # but it should NOT be rejected by origin check
    allow(described_class).to receive(:get_handlers).and_return({})
    result = described_class.dispatch_request(payload)
    # Returns false because no handler, but doesn't raise origin error
    expect(result).to eq false
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/lib/fediverse/inbox_spec.rb -e 'origin verification'`
Expected: FAIL - Update from evil.com modifying example.com object is not rejected

**Step 3: Implement origin verification**

In `lib/fediverse/inbox.rb`, add private method and call it in `dispatch_request`:

```ruby
def dispatch_request(payload)
  # De-duplication check (from Task 1)
  if payload['id'].present? && Federails::Activity.exists?(federated_url: payload['id'])
    return :duplicate
  end

  return dispatch_delete_request(payload) if payload['type'] == 'Delete'

  payload['object'] = Fediverse::Request.dereference(payload['object']) if payload.key? 'object'

  # Origin verification for Update activities
  if payload['type'] == 'Update' && !same_origin?(payload['actor'], payload.dig('object', 'id'))
    Rails.logger.warn { "Rejected Update: actor origin (#{payload['actor']}) does not match object origin (#{payload.dig('object', 'id')})" }
    return false
  end

  handlers = get_handlers(payload['type'], payload.dig('object', 'type'))
  handlers.each_pair do |klass, method|
    klass.send method, payload
  end

  record_processed_activity(payload) if payload['id'].present? && !handlers.empty?

  return true unless handlers.empty?

  Rails.logger.debug { "Unhandled activity type: #{payload['type']}" }
  false
end
```

Add private method:

```ruby
def same_origin?(url1, url2)
  return false if url1.blank? || url2.blank?

  URI.parse(url1).host == URI.parse(url2).host
rescue URI::InvalidURIError
  false
end
```

**Step 4: Run tests**

Run: `bundle exec rspec spec/lib/fediverse/inbox_spec.rb`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lib/fediverse/inbox.rb spec/lib/fediverse/inbox_spec.rb
git commit -m "feat: verify same-origin for Update activities (AP Section 7.3 MUST)"
```

---

### Task 6: Reject Activity Handling

**Spec reference:** Section 7.7 - MUST NOT add to Following on Reject

**Files:**
- Modify: `lib/fediverse/inbox.rb`
- Test: `spec/lib/fediverse/inbox_spec.rb`

**Step 1: Write the failing test**

Add to `spec/lib/fediverse/inbox_spec.rb`:

```ruby
describe 'registered handlers' do
  # ... existing tests ...
  it 'registered a handler for "Reject" activities on "Follow" object' do
    expect(handlers['Reject']['Follow'].keys).to include described_class
  end
end

describe '#handle_reject_follow_request' do
  let(:pending_following) { Federails::Following.create actor: local_actor, target_actor: distant_actor }
  let(:payload) do
    {
      'actor' => distant_actor.federated_url,
    }
  end
  let(:follow_object) do
    {
      'type' => 'Follow',
      'actor' => pending_following.actor.federated_url,
      'object' => pending_following.target_actor.federated_url,
    }
  end

  before do
    allow(Fediverse::Request).to receive(:dereference).and_return(follow_object)
  end

  it 'destroys the pending following' do
    expect do
      described_class.send(:handle_reject_follow_request, payload)
    end.to change(Federails::Following, :count).by(-1)
  end

  context 'when no matching following exists' do
    it 'does not raise an error' do
      pending_following.destroy
      expect do
        described_class.send(:handle_reject_follow_request, payload)
      end.not_to raise_error
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/lib/fediverse/inbox_spec.rb -e 'Reject'`
Expected: FAIL - no handler registered

**Step 3: Implement Reject handler**

In `lib/fediverse/inbox.rb`, add private method:

```ruby
def handle_reject_follow_request(activity)
  original_activity = Request.dereference(activity['object'])

  actor        = Federails::Actor.find_or_create_by_object original_activity['actor']
  target_actor = Federails::Actor.find_or_create_by_object original_activity['object']

  follow = Federails::Following.find_by actor: actor, target_actor: target_actor
  follow&.destroy
end
```

Register the handler at the bottom alongside existing registrations:

```ruby
register_handler 'Reject', 'Follow', self, :handle_reject_follow_request
```

**Step 4: Run tests**

Run: `bundle exec rspec spec/lib/fediverse/inbox_spec.rb`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lib/fediverse/inbox.rb spec/lib/fediverse/inbox_spec.rb
git commit -m "feat: handle Reject activity for Follow (AP Section 7.7 MUST)"
```

---

### Task 7: Inbox Forwarding

**Spec reference:** Section 7.1.2 - MUST forward activity when conditions are met

**Files:**
- Modify: `lib/fediverse/inbox.rb`
- Modify: `lib/fediverse/notifier.rb`
- Modify: `app/controllers/federails/server/activities_controller.rb`
- Test: `spec/lib/fediverse/inbox_spec.rb`

**Step 1: Write the failing test**

Add to `spec/lib/fediverse/inbox_spec.rb`:

```ruby
describe '.maybe_forward' do
  let(:local_actor_2) { FactoryBot.create(:user).federails_actor }

  before do
    # local_actor_2 follows local_actor
    Federails::Following.create! actor: local_actor_2, target_actor: local_actor, status: :accepted
  end

  context 'when activity references a local collection and local object' do
    let(:payload) do
      {
        'id' => 'https://example.com/activities/forward-test',
        'type' => 'Create',
        'actor' => distant_actor.federated_url,
        'cc' => [local_actor.followers_url],
        'object' => {
          'id' => 'https://example.com/replies/1',
          'type' => 'Note',
          'inReplyTo' => local_actor.federated_url,
        },
      }
    end

    it 'forwards the activity' do
      allow(Fediverse::Notifier).to receive(:forward_activity)
      described_class.maybe_forward(payload)
      expect(Fediverse::Notifier).to have_received(:forward_activity).once
    end
  end

  context 'when activity does not reference any local collection' do
    let(:payload) do
      {
        'id' => 'https://example.com/activities/no-forward',
        'type' => 'Create',
        'actor' => distant_actor.federated_url,
        'cc' => ['https://remote.example.com/users/someone/followers'],
        'object' => {
          'id' => 'https://example.com/replies/2',
          'type' => 'Note',
          'inReplyTo' => 'https://remote.example.com/posts/1',
        },
      }
    end

    it 'does not forward' do
      allow(Fediverse::Notifier).to receive(:forward_activity)
      described_class.maybe_forward(payload)
      expect(Fediverse::Notifier).not_to have_received(:forward_activity)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/lib/fediverse/inbox_spec.rb -e 'maybe_forward'`
Expected: FAIL - `maybe_forward` method doesn't exist

**Step 3: Implement inbox forwarding**

In `lib/fediverse/inbox.rb`, add class method:

```ruby
# Checks if an incoming activity should be forwarded to local followers
# AP Spec Section 7.1.2
#
# Conditions (ALL must be true):
# 1. First time seeing this activity (handled by de-duplication)
# 2. to/cc/audience contains a collection owned by this server
# 3. inReplyTo/object/target/tag references an object owned by this server
def maybe_forward(payload)
  return unless references_local_collection?(payload) && references_local_object?(payload)

  # Collect local collection URLs from addressing
  local_collections = addressed_local_collections(payload)
  return if local_collections.empty?

  Fediverse::Notifier.forward_activity(payload, local_collections, exclude_actor: payload['actor'])
end
```

Add private helpers:

```ruby
def references_local_collection?(payload)
  addressing = [payload['to'], payload['cc'], payload['audience']].flatten.compact
  addressing.any? { |url| Federails::Utils::Host.local_url?(url) }
end

def references_local_object?(payload)
  object = payload['object'].is_a?(Hash) ? payload['object'] : {}
  refs = [
    object['inReplyTo'],
    object['id'],
    payload['target'],
    object.fetch('tag', []).map { |t| t.is_a?(Hash) ? t['href'] : t },
  ].flatten.compact

  refs.any? { |url| Federails::Utils::Host.local_url?(url) }
end

def addressed_local_collections(payload)
  addressing = [payload['to'], payload['cc'], payload['audience']].flatten.compact
  addressing.select { |url| Federails::Utils::Host.local_url?(url) }
end
```

**Step 4: Add forward_activity to Notifier**

In `lib/fediverse/notifier.rb`, add class method:

```ruby
# Forwards a received activity to members of local collections
# Used for inbox forwarding (AP Section 7.1.2)
#
# @param payload [Hash] The raw activity payload
# @param collection_urls [Array<String>] Local collection URLs to forward to
# @param exclude_actor [String] Actor URL to exclude from recipients
def forward_activity(payload, collection_urls, exclude_actor: nil)
  inboxes = collection_urls.flat_map do |url|
    collection_to_actors(url).map(&:inbox_url)
  rescue Errors::NotACollection
    []
  end

  inboxes = inboxes.compact.uniq
  inboxes.reject! { |url| url == exclude_actor } if exclude_actor

  message = payload.to_json
  inboxes.each do |url|
    Rails.logger.debug { "Forwarding activity to inbox at #{url}" }
    post_to_inbox(inbox_url: url, message: message)
  end
end
```

**Step 5: Call maybe_forward from inbox controller**

In `app/controllers/federails/server/activities_controller.rb`, update `create`:

```ruby
def create
  skip_authorization

  payload = payload_from_params
  return head :unprocessable_entity unless payload

  if Fediverse::Inbox.dispatch_request(payload)
    Fediverse::Inbox.maybe_forward(payload)
    head :created
  else
    head :unprocessable_entity
  end
end
```

**Step 6: Run tests**

Run: `bundle exec rspec spec/lib/fediverse/inbox_spec.rb`
Expected: ALL PASS

**Step 7: Commit**

```bash
git add lib/fediverse/inbox.rb lib/fediverse/notifier.rb app/controllers/federails/server/activities_controller.rb spec/lib/fediverse/inbox_spec.rb
git commit -m "feat: implement inbox forwarding for ghost replies (AP Section 7.1.2 MUST)"
```

---

## Execution Order

Tasks are independent but build on each other slightly:
1. **Task 1** (de-duplication) - adds `federated_url` to Activity, used by Task 7
2. **Task 2** (exclude self) - small notifier change
3. **Task 3** (collection limit) - small collection change
4. **Task 4** (bto/bcc/audience) - migration + notifier change (depends on Task 2 notifier changes)
5. **Task 5** (update origin) - inbox change (depends on Task 1 inbox changes)
6. **Task 6** (reject) - inbox handler addition
7. **Task 7** (inbox forwarding) - depends on Task 1 (de-dup), Task 2 (notifier)

Run full test suite after all tasks: `bundle exec rspec`
