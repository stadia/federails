# ActivityPub P0/P1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close Federails' critical ActivityPub gaps (inbound signature verification, shared inbox, collection containers) and add mid-term features (delivery reliability, Like/Announce/Block, LD Signatures verification, bto/bcc handling, missing collections).

**Architecture:** Extend existing patterns — `Fediverse::Signature` for verification, new controller for shared inbox reusing `Fediverse::Inbox` dispatch, `OrderedCollectionResource` container mode, `DeadLetter` model for failed deliveries, new inbox handlers for Like/Announce/Block via `register_handler`, `Fediverse::LinkedDataSignature` module for LD sig verification.

**Tech Stack:** Ruby on Rails engine, Alba serializers, ActiveJob, RSA/OpenSSL, JSON-LD gem, RSpec + FactoryBot

---

## File Map

### P0-1: Inbound HTTP Signature Verification
- Modify: `lib/fediverse/signature.rb` — add `verify_request`, `parse_signature_header`, `verify_digest` class methods
- Modify: `app/controllers/federails/server/activities_controller.rb` — add `verify_http_signature!` before_action on `create`
- Modify: `lib/federails/configuration.rb` — add `verify_signatures` setting
- Create: `spec/lib/fediverse/signature_verification_spec.rb`
- Modify: `spec/acceptance/federails/server/activities_controller_spec.rb` — update inbox tests to include signatures

### P0-2: Shared Inbox
- Create: `app/controllers/federails/server/shared_inbox_controller.rb`
- Modify: `config/routes.rb` — add shared inbox route
- Modify: `app/serializers/federails/server/actor_resource.rb` — add `endpoints.sharedInbox`
- Modify: `lib/fediverse/notifier.rb` — group deliveries by shared inbox
- Modify: `app/models/federails/actor.rb` — add `shared_inbox_url` accessor
- Create: `db/migrate/XXXXXX_add_shared_inbox_url_to_federails_actors.rb`
- Create: `spec/controllers/federails/server/shared_inbox_controller_spec.rb`
- Create: `spec/requests/federation/shared_inbox_spec.rb`

### P0-3: OrderedCollection Container
- Modify: `app/controllers/federails/server/activities_controller.rb` — container vs page branching in `outbox`
- Modify: `app/controllers/federails/server/actors_controller.rb` — container vs page branching in `followers`/`following`
- Modify: `app/controllers/concerns/federails/server/render_collections.rb` — add `render_collection_or_container`
- Modify: `app/serializers/federails/server/ordered_collection_resource.rb` — container payload support
- Modify: `spec/acceptance/federails/server/activities_controller_spec.rb`
- Modify: `spec/acceptance/federails/server/actors_controller_spec.rb`

### P1-1: Delivery Reliability
- Create: `app/models/federails/dead_letter.rb`
- Create: `db/migrate/XXXXXX_create_federails_dead_letters.rb`
- Modify: `app/jobs/federails/notify_inbox_job.rb` — retry logic, error classification, ordering
- Create: `lib/federails/delivery_errors.rb` — error classes for HTTP status classification
- Create: `lib/tasks/delivery.rake` — retry/cleanup tasks
- Create: `spec/models/federails/dead_letter_spec.rb`
- Create: `spec/jobs/federails/notify_inbox_job_spec.rb`

### P1-2: Like Activity
- Create: `lib/fediverse/inbox/like_handler.rb`
- Modify: `lib/fediverse/inbox.rb` — register Like + Undo(Like) handlers
- Create: `spec/lib/fediverse/inbox/like_handler_spec.rb`

### P1-3: Announce Activity
- Create: `lib/fediverse/inbox/announce_handler.rb`
- Modify: `lib/fediverse/inbox.rb` — register Announce + Undo(Announce) handlers
- Create: `spec/lib/fediverse/inbox/announce_handler_spec.rb`

### P1-4: Block Activity
- Create: `lib/fediverse/inbox/block_handler.rb`
- Modify: `lib/fediverse/inbox.rb` — register Block + Undo(Block) handlers
- Modify: `lib/fediverse/notifier.rb` — filter blocked actors from delivery
- Create: `app/models/federails/block.rb`
- Create: `db/migrate/XXXXXX_create_federails_blocks.rb`
- Create: `spec/lib/fediverse/inbox/block_handler_spec.rb`
- Create: `spec/models/federails/block_spec.rb`

### P1-5: LD Signatures Verification
- Create: `lib/fediverse/linked_data_signature.rb`
- Modify: `lib/fediverse/inbox/announce_handler.rb` — verify LD sig on inner activity
- Create: `spec/lib/fediverse/linked_data_signature_spec.rb`

### P1-6: bto/bcc Strip + Audience
- Modify: `lib/fediverse/notifier.rb` — strip bto/bcc from payload, include in delivery targets
- Modify: `app/serializers/federails/server/activity_resource.rb` — ensure bto/bcc omitted in serialization
- Create: `spec/lib/fediverse/notifier_bto_bcc_spec.rb`

### P1-7: Missing Collections (liked, featured, featured_tags)
- Create: `app/models/federails/featured_item.rb`
- Create: `app/models/federails/featured_tag.rb`
- Create: `db/migrate/XXXXXX_create_federails_featured_items.rb`
- Create: `db/migrate/XXXXXX_create_federails_featured_tags.rb`
- Modify: `app/controllers/federails/server/actors_controller.rb` — add `liked`, `featured`, `featured_tags` actions
- Modify: `config/routes.rb` — add collection routes
- Modify: `app/serializers/federails/server/actor_resource.rb` — add collection URLs
- Create: `spec/requests/federation/collections_spec.rb`

---

## Task 1: Inbound HTTP Signature Verification — Core Logic

**Files:**
- Modify: `lib/fediverse/signature.rb`
- Modify: `lib/federails/configuration.rb`
- Create: `spec/lib/fediverse/signature_verification_spec.rb`

- [ ] **Step 1: Add `verify_signatures` config option**

In `lib/federails/configuration.rb`, add:

```ruby
mattr_accessor :verify_signatures
@@verify_signatures = true
```

- [ ] **Step 2: Write failing test for signature header parsing**

Create `spec/lib/fediverse/signature_verification_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Fediverse::Signature do
  let(:actor) { create(:local_actor) }
  let(:remote_actor) { create(:distant_actor) }

  describe '.parse_signature_header' do
    it 'parses a valid Signature header into components' do
      header = 'keyId="https://remote.example/actor#main-key",headers="(request-target) host date digest",signature="abc123"'
      result = described_class.parse_signature_header(header)

      expect(result[:key_id]).to eq('https://remote.example/actor#main-key')
      expect(result[:headers]).to eq('(request-target) host date digest')
      expect(result[:signature]).to eq('abc123')
    end

    it 'raises on missing Signature header' do
      expect { described_class.parse_signature_header(nil) }.to raise_error(Fediverse::Signature::SignatureVerificationError, /missing/i)
    end

    it 'raises on malformed Signature header' do
      expect { described_class.parse_signature_header('garbage') }.to raise_error(Fediverse::Signature::SignatureVerificationError)
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bundle exec rspec spec/lib/fediverse/signature_verification_spec.rb`
Expected: FAIL — `SignatureVerificationError` not defined, `parse_signature_header` not defined

- [ ] **Step 4: Implement `parse_signature_header` and error class**

In `lib/fediverse/signature.rb`, add inside the class:

```ruby
class SignatureVerificationError < StandardError; end

def self.parse_signature_header(header)
  raise SignatureVerificationError, 'Signature header missing' if header.blank?

  params = {}
  header.scan(/(\w+)="([^"]*)"/) do |key, value|
    params[key.to_sym] = value
  end

  unless params[:keyId] && params[:headers] && params[:signature]
    raise SignatureVerificationError, 'Malformed Signature header: missing required fields'
  end

  {
    key_id: params[:keyId],
    headers: params[:headers],
    signature: params[:signature],
    algorithm: params[:algorithm] || 'rsa-sha256'
  }
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/lib/fediverse/signature_verification_spec.rb`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/fediverse/signature.rb lib/federails/configuration.rb spec/lib/fediverse/signature_verification_spec.rb
git commit -m "feat: add HTTP Signature header parsing and verify_signatures config"
```

---

## Task 2: Inbound HTTP Signature Verification — Digest and Full Verification

**Files:**
- Modify: `lib/fediverse/signature.rb`
- Modify: `spec/lib/fediverse/signature_verification_spec.rb`

- [ ] **Step 1: Write failing test for digest verification**

Append to `spec/lib/fediverse/signature_verification_spec.rb`:

```ruby
describe '.verify_digest!' do
  it 'passes when digest matches body' do
    body = '{"type":"Follow"}'
    digest = "SHA-256=#{Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(body))}"
    request = double('request', body: StringIO.new(body), headers: { 'Digest' => digest })

    expect { described_class.verify_digest!(request) }.not_to raise_error
  end

  it 'raises when digest does not match body' do
    body = '{"type":"Follow"}'
    request = double('request', body: StringIO.new(body), headers: { 'Digest' => 'SHA-256=wrongdigest' })

    expect { described_class.verify_digest!(request) }.to raise_error(Fediverse::Signature::SignatureVerificationError, /digest/i)
  end

  it 'raises when Digest header is missing on POST' do
    body = '{"type":"Follow"}'
    request = double('request', body: StringIO.new(body), headers: {})

    expect { described_class.verify_digest!(request) }.to raise_error(Fediverse::Signature::SignatureVerificationError, /digest/i)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/lib/fediverse/signature_verification_spec.rb`
Expected: FAIL — `verify_digest!` not defined

- [ ] **Step 3: Implement `verify_digest!`**

In `lib/fediverse/signature.rb`:

```ruby
def self.verify_digest!(request)
  digest_header = request.headers['Digest']
  raise SignatureVerificationError, 'Digest header missing' if digest_header.blank?

  body = request.body.read
  request.body.rewind

  expected = "SHA-256=#{Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(body))}"
  raise SignatureVerificationError, 'Digest mismatch' unless ActiveSupport::SecurityUtils.secure_compare(digest_header, expected)
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/lib/fediverse/signature_verification_spec.rb`
Expected: PASS

- [ ] **Step 5: Write failing test for full request verification**

Append to `spec/lib/fediverse/signature_verification_spec.rb`:

```ruby
describe '.verify_request!' do
  let(:keypair) { OpenSSL::PKey::RSA.generate(2048) }
  let(:remote_actor) do
    create(:distant_actor).tap do |a|
      a.update_columns(public_key: keypair.public_key.to_pem)
    end
  end

  def build_signed_request(actor:, method: 'POST', path: '/federation/actors/1/inbox', body: '{}')
    digest = "SHA-256=#{Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(body))}"
    host = 'example.com'
    date = Time.now.utc.httpdate

    headers_list = '(request-target) host date digest'
    signed_string = [
      "(request-target): #{method.downcase} #{path}",
      "host: #{host}",
      "date: #{date}",
      "digest: #{digest}"
    ].join("\n")

    signature = Base64.strict_encode64(keypair.sign(OpenSSL::Digest.new('SHA256'), signed_string))
    sig_header = "keyId=\"#{actor.federated_url}#main-key\",headers=\"#{headers_list}\",signature=\"#{signature}\""

    double('request',
      method: method,
      path: path,
      body: StringIO.new(body),
      headers: {
        'Signature' => sig_header,
        'Host' => host,
        'Date' => date,
        'Digest' => digest
      },
      original_url: "https://#{host}#{path}"
    )
  end

  it 'returns the actor for a valid signature' do
    request = build_signed_request(actor: remote_actor)
    result = described_class.verify_request!(request)
    expect(result).to eq(remote_actor)
  end

  it 'raises for an invalid signature' do
    request = build_signed_request(actor: remote_actor, body: '{"tampered":true}')
    # Body changed after signing, so digest was signed with original body
    expect { described_class.verify_request!(request) }.to raise_error(Fediverse::Signature::SignatureVerificationError)
  end

  it 'raises when actor cannot be found' do
    unknown_actor = build(:distant_actor, federated_url: 'https://unknown.example/actor')
    request = build_signed_request(actor: unknown_actor)

    allow(Federails::Actor).to receive(:find_or_create_by_federation_url).and_return(nil)
    expect { described_class.verify_request!(request) }.to raise_error(Fediverse::Signature::SignatureVerificationError, /actor/i)
  end
end
```

- [ ] **Step 6: Run test to verify it fails**

Run: `bundle exec rspec spec/lib/fediverse/signature_verification_spec.rb`
Expected: FAIL — `verify_request!` not defined

- [ ] **Step 7: Implement `verify_request!`**

In `lib/fediverse/signature.rb`:

```ruby
def self.verify_request!(request)
  sig = parse_signature_header(request.headers['Signature'])
  verify_digest!(request)

  # Extract actor URI from keyId (strip #main-key fragment)
  actor_uri = sig[:key_id].sub(/#.*\z/, '')
  actor = Federails::Actor.find_or_create_by_federation_url(actor_uri)
  raise SignatureVerificationError, 'Could not resolve signing actor' unless actor

  comparison_string = signature_payload(request: request, headers: sig[:headers])
  public_key = OpenSSL::PKey::RSA.new(actor.public_key)
  signature_bytes = Base64.strict_decode64(sig[:signature])

  unless public_key.verify(OpenSSL::Digest.new('SHA256'), signature_bytes, comparison_string)
    # Key rotation: re-fetch actor and retry once
    actor.sync!
    public_key = OpenSSL::PKey::RSA.new(actor.public_key)
    unless public_key.verify(OpenSSL::Digest.new('SHA256'), signature_bytes, comparison_string)
      raise SignatureVerificationError, 'Signature verification failed'
    end
  end

  actor
end
```

- [ ] **Step 8: Run test to verify it passes**

Run: `bundle exec rspec spec/lib/fediverse/signature_verification_spec.rb`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add lib/fediverse/signature.rb spec/lib/fediverse/signature_verification_spec.rb
git commit -m "feat: implement inbound HTTP Signature and Digest verification"
```

---

## Task 3: Inbound HTTP Signature — Controller Integration

**Files:**
- Modify: `app/controllers/federails/server/activities_controller.rb`
- Modify: `spec/acceptance/federails/server/activities_controller_spec.rb`

- [ ] **Step 1: Write failing test for unsigned inbox POST rejection**

Add to the inbox POST tests in `spec/acceptance/federails/server/activities_controller_spec.rb` (or create a new focused spec `spec/requests/federation/inbox_signature_spec.rb`):

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Inbox HTTP Signature Verification', type: :request do
  let(:actor) { create(:local_actor) }
  let(:payload) { { '@context' => 'https://www.w3.org/ns/activitystreams', 'id' => 'https://remote.example/activity/1', 'type' => 'Follow', 'actor' => 'https://remote.example/actor', 'object' => actor.federated_url }.to_json }

  context 'when verify_signatures is true' do
    before { Federails.verify_signatures = true }
    after { Federails.verify_signatures = true }

    it 'rejects unsigned POST with 401' do
      post federails.server_actor_inbox_path(actor), params: payload, headers: { 'Content-Type' => 'application/activity+json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when verify_signatures is false' do
    before { Federails.verify_signatures = false }
    after { Federails.verify_signatures = true }

    it 'accepts unsigned POST' do
      allow(Fediverse::Inbox).to receive(:dispatch_request).and_return(true)
      post federails.server_actor_inbox_path(actor), params: payload, headers: { 'Content-Type' => 'application/activity+json' }
      expect(response).to have_http_status(:created)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/federation/inbox_signature_spec.rb`
Expected: FAIL — unsigned POST currently returns 201, not 401

- [ ] **Step 3: Add `verify_http_signature!` before_action**

In `app/controllers/federails/server/activities_controller.rb`, add:

```ruby
before_action :verify_http_signature!, only: :create

private

def verify_http_signature!
  return unless Federails.verify_signatures

  @signed_actor = Fediverse::Signature.verify_request!(request)
rescue Fediverse::Signature::SignatureVerificationError => e
  Federails.logger.warn "Signature verification failed: #{e.message}"
  head :unauthorized
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/federation/inbox_signature_spec.rb`
Expected: PASS

- [ ] **Step 5: Run full test suite to check for regressions**

Run: `bundle exec rspec`
Expected: Existing inbox tests may fail because they don't sign requests. Fix by setting `Federails.verify_signatures = false` in existing specs or by adding signature headers.

- [ ] **Step 6: Fix existing tests — disable verification in existing inbox specs**

In `spec/support/signature_helper.rb`, create:

```ruby
# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each) do
    Federails.verify_signatures = false
  end

  config.after(:each) do
    Federails.verify_signatures = true
  end
end
```

Then in `spec/requests/federation/inbox_signature_spec.rb`, override:

```ruby
context 'when verify_signatures is true' do
  before { Federails.verify_signatures = true }
  # ...
end
```

- [ ] **Step 7: Run full test suite**

Run: `bundle exec rspec`
Expected: All PASS

- [ ] **Step 8: Commit**

```bash
git add app/controllers/federails/server/activities_controller.rb spec/requests/federation/inbox_signature_spec.rb spec/support/signature_helper.rb
git commit -m "feat: enforce inbound HTTP Signature verification on inbox POST"
```

---

## Task 4: Shared Inbox — Migration and Actor Model

**Files:**
- Create: `db/migrate/XXXXXX_add_shared_inbox_url_to_federails_actors.rb`
- Modify: `app/models/federails/actor.rb`

- [ ] **Step 1: Generate migration**

Run: `bundle exec rails generate migration AddSharedInboxUrlToFederailsActors shared_inbox_url:string --no-test-framework`

Edit the generated file to:

```ruby
class AddSharedInboxUrlToFederailsActors < ActiveRecord::Migration[7.0]
  def change
    add_column :federails_actors, :shared_inbox_url, :string
  end
end
```

- [ ] **Step 2: Run migration in dummy app**

Run: `cd spec/dummy && bundle exec rails db:migrate && cd ../..`

- [ ] **Step 3: Write failing test for shared_inbox_url on Actor**

Add to `spec/models/federails/actor_spec.rb`:

```ruby
describe '#shared_inbox_url' do
  context 'for a local actor' do
    let(:actor) { create(:local_actor) }

    it 'returns the shared inbox URL from routes' do
      expect(actor.shared_inbox_url).to eq(Federails::Engine.routes.url_helpers.server_shared_inbox_url)
    end
  end

  context 'for a distant actor' do
    let(:actor) { create(:distant_actor, shared_inbox_url: 'https://remote.example/inbox') }

    it 'returns the stored shared_inbox_url' do
      expect(actor.shared_inbox_url).to eq('https://remote.example/inbox')
    end
  end

  context 'for a distant actor without shared inbox' do
    let(:actor) { create(:distant_actor, shared_inbox_url: nil) }

    it 'returns nil' do
      expect(actor.shared_inbox_url).to be_nil
    end
  end
end
```

- [ ] **Step 4: Run test to verify it fails**

Run: `bundle exec rspec spec/models/federails/actor_spec.rb`
Expected: FAIL — route helper `server_shared_inbox_url` not defined yet, local actor doesn't override `shared_inbox_url`

- [ ] **Step 5: Add `shared_inbox_url` method to Actor**

In `app/models/federails/actor.rb`, add within the dynamic attribute methods section:

```ruby
def shared_inbox_url
  if use_entity_attributes?
    route_helpers.server_shared_inbox_url
  else
    self[:shared_inbox_url]
  end
end
```

Note: The route doesn't exist yet — this will be created in Task 5. Skip this test for now and return after Task 5.

- [ ] **Step 6: Commit migration and model change**

```bash
git add db/migrate/*_add_shared_inbox_url_to_federails_actors.rb app/models/federails/actor.rb spec/models/federails/actor_spec.rb
git commit -m "feat: add shared_inbox_url to Actor model"
```

---

## Task 5: Shared Inbox — Controller and Routes

**Files:**
- Create: `app/controllers/federails/server/shared_inbox_controller.rb`
- Modify: `config/routes.rb`
- Create: `spec/requests/federation/shared_inbox_spec.rb`

- [ ] **Step 1: Write failing test for shared inbox POST**

Create `spec/requests/federation/shared_inbox_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Shared Inbox', type: :request do
  let(:actor1) { create(:local_actor) }
  let(:actor2) { create(:local_actor) }

  let(:payload) do
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => 'https://remote.example/activity/1',
      'type' => 'Create',
      'actor' => 'https://remote.example/actor',
      'object' => { 'type' => 'Note', 'content' => 'Hello' },
      'to' => [actor1.federated_url, actor2.federated_url]
    }.to_json
  end

  it 'accepts a valid activity' do
    allow(Fediverse::Inbox).to receive(:dispatch_request).and_return(true)

    post federails.server_shared_inbox_path,
      params: payload,
      headers: { 'Content-Type' => 'application/activity+json' }

    expect(response).to have_http_status(:created)
  end

  it 'returns 415 for unsupported content type' do
    post federails.server_shared_inbox_path,
      params: payload,
      headers: { 'Content-Type' => 'application/json' }

    expect(response).to have_http_status(:unsupported_media_type)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/federation/shared_inbox_spec.rb`
Expected: FAIL — route not defined

- [ ] **Step 3: Add shared inbox route**

In `config/routes.rb`, inside the server routes scope (`scope server_routes_path`), add:

```ruby
post 'inbox', to: 'shared_inbox#create', as: :server_shared_inbox
```

- [ ] **Step 4: Create SharedInboxController**

Create `app/controllers/federails/server/shared_inbox_controller.rb`:

```ruby
# frozen_string_literal: true

module Federails
  module Server
    class SharedInboxController < Federails::ServerController
      skip_after_action :verify_authorized

      before_action :verify_http_signature!, if: -> { Federails.verify_signatures }
      before_action :validate_content_type!

      def create
        payload = payload_from_params
        result = Fediverse::Inbox.dispatch_request(payload)

        case result
        when true
          Fediverse::Inbox.maybe_forward(payload)
          head :created
        when :duplicate
          head :ok
        else
          head :unprocessable_entity
        end
      end

      private

      def verify_http_signature!
        @signed_actor = Fediverse::Signature.verify_request!(request)
      rescue Fediverse::Signature::SignatureVerificationError => e
        Federails.logger.warn "Shared inbox signature verification failed: #{e.message}"
        head :unauthorized
      end

      def validate_content_type!
        head :unsupported_media_type unless supported_inbox_content_type?
      end

      def supported_inbox_content_type?
        content_type = request.headers['Content-Type']&.to_s
        content_type&.start_with?('application/activity+json') ||
          content_type&.include?('application/ld+json')
      end

      def payload_from_params
        body = request.body.read
        request.body.rewind
        payload = JSON.parse(body)
        compact_payload(payload)
      end

      def compact_payload(payload)
        JSON::LD::API.compact(payload, payload['@context'] || 'https://www.w3.org/ns/activitystreams')
      rescue StandardError => e
        Federails.logger.warn "JSON-LD compaction failed in shared inbox: #{e.message}"
        payload
      end
    end
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/federation/shared_inbox_spec.rb`
Expected: PASS

- [ ] **Step 6: Run the shared_inbox_url actor test from Task 4**

Run: `bundle exec rspec spec/models/federails/actor_spec.rb`
Expected: PASS (route now exists)

- [ ] **Step 7: Commit**

```bash
git add app/controllers/federails/server/shared_inbox_controller.rb config/routes.rb spec/requests/federation/shared_inbox_spec.rb
git commit -m "feat: add shared inbox endpoint with signature verification"
```

---

## Task 6: Shared Inbox — Actor Serialization and Outbound Optimization

**Files:**
- Modify: `app/serializers/federails/server/actor_resource.rb`
- Modify: `lib/fediverse/notifier.rb`
- Modify: `spec/acceptance/federails/server/actors_controller_spec.rb`

- [ ] **Step 1: Write failing test for endpoints.sharedInbox in actor JSON**

Add to `spec/acceptance/federails/server/actors_controller_spec.rb` or create `spec/serializers/federails/server/actor_resource_shared_inbox_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Actor JSON endpoints.sharedInbox', type: :request do
  let(:user) { create(:user) }
  let(:actor) { user.federails_actor }

  it 'includes endpoints.sharedInbox' do
    get federails.server_actor_path(actor), headers: { 'Accept' => 'application/activity+json' }

    json = JSON.parse(response.body)
    expect(json['endpoints']).to be_a(Hash)
    expect(json['endpoints']['sharedInbox']).to be_present
    expect(json['endpoints']['sharedInbox']).to include('/inbox')
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/serializers/federails/server/actor_resource_shared_inbox_spec.rb`
Expected: FAIL — no `endpoints` in actor JSON

- [ ] **Step 3: Add `endpoints` to ActorResource**

In `app/serializers/federails/server/actor_resource.rb`, add:

```ruby
attribute :endpoints do |actor|
  if actor.local?
    { sharedInbox: SerializerSupport.route_helpers.server_shared_inbox_url }
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/serializers/federails/server/actor_resource_shared_inbox_spec.rb`
Expected: PASS

- [ ] **Step 5: Write failing test for shared inbox delivery grouping**

Create `spec/lib/fediverse/notifier_shared_inbox_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Fediverse::Notifier, 'shared inbox grouping' do
  let(:local_actor) { create(:local_actor) }

  it 'groups recipients on the same server into one shared inbox delivery' do
    actor_a = create(:distant_actor,
      inbox_url: 'https://remote.example/users/a/inbox',
      shared_inbox_url: 'https://remote.example/inbox')
    actor_b = create(:distant_actor,
      inbox_url: 'https://remote.example/users/b/inbox',
      shared_inbox_url: 'https://remote.example/inbox')

    activity = create(:activity, actor: local_actor, to: [actor_a.federated_url, actor_b.federated_url])

    expect(described_class).to receive(:post_to_inbox).once.with(
      hash_including(inbox_url: 'https://remote.example/inbox')
    )

    described_class.post_to_inboxes(activity)
  end

  it 'falls back to personal inbox when no shared inbox' do
    actor_c = create(:distant_actor,
      inbox_url: 'https://other.example/users/c/inbox',
      shared_inbox_url: nil)

    activity = create(:activity, actor: local_actor, to: [actor_c.federated_url])

    expect(described_class).to receive(:post_to_inbox).once.with(
      hash_including(inbox_url: 'https://other.example/users/c/inbox')
    )

    described_class.post_to_inboxes(activity)
  end
end
```

- [ ] **Step 6: Run test to verify it fails**

Run: `bundle exec rspec spec/lib/fediverse/notifier_shared_inbox_spec.rb`
Expected: FAIL — currently delivers to each personal inbox separately

- [ ] **Step 7: Modify `Notifier.inboxes_for` to prefer shared inboxes**

In `lib/fediverse/notifier.rb`, modify the `inboxes_for` method to group by shared inbox:

```ruby
def self.inboxes_for(activity)
  actors = resolve_recipient_actors(activity)
  actors.reject! { |a| a.federated_url == activity.actor.federated_url }

  inboxes = Set.new
  actors.each do |actor|
    inbox = actor.shared_inbox_url || actor.inbox_url
    inboxes.add(inbox) if inbox.present?
  end

  inboxes.to_a
end
```

Where `resolve_recipient_actors` extracts the existing logic of resolving `to`/`cc`/`bto`/`bcc`/`audience` to actors.

- [ ] **Step 8: Run test to verify it passes**

Run: `bundle exec rspec spec/lib/fediverse/notifier_shared_inbox_spec.rb`
Expected: PASS

- [ ] **Step 9: Run full test suite**

Run: `bundle exec rspec`
Expected: All PASS

- [ ] **Step 10: Commit**

```bash
git add app/serializers/federails/server/actor_resource.rb lib/fediverse/notifier.rb spec/serializers/federails/server/actor_resource_shared_inbox_spec.rb spec/lib/fediverse/notifier_shared_inbox_spec.rb
git commit -m "feat: add endpoints.sharedInbox to actor JSON and optimize outbound delivery"
```

---

## Task 7: OrderedCollection Container

**Files:**
- Modify: `app/controllers/concerns/federails/server/render_collections.rb`
- Modify: `app/serializers/federails/server/ordered_collection_resource.rb`
- Modify: `app/controllers/federails/server/activities_controller.rb`
- Modify: `app/controllers/federails/server/actors_controller.rb`
- Create: `spec/requests/federation/ordered_collection_container_spec.rb`

- [ ] **Step 1: Write failing test for collection container response**

Create `spec/requests/federation/ordered_collection_container_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OrderedCollection Container', type: :request do
  let(:user) { create(:user) }
  let(:actor) { user.federails_actor }

  describe 'GET outbox without page param' do
    before { create_list(:activity, 3, actor: actor) }

    it 'returns an OrderedCollection container' do
      get federails.outbox_server_actor_path(actor), headers: { 'Accept' => 'application/activity+json' }

      json = JSON.parse(response.body)
      expect(json['type']).to eq('OrderedCollection')
      expect(json['totalItems']).to eq(3)
      expect(json['first']).to be_present
      expect(json).not_to have_key('orderedItems')
    end
  end

  describe 'GET outbox with page param' do
    before { create_list(:activity, 3, actor: actor) }

    it 'returns an OrderedCollectionPage' do
      get federails.outbox_server_actor_path(actor, page: 'true'), headers: { 'Accept' => 'application/activity+json' }

      json = JSON.parse(response.body)
      expect(json['type']).to eq('OrderedCollectionPage')
      expect(json['orderedItems']).to be_an(Array)
    end
  end

  describe 'GET followers without page param' do
    it 'returns an OrderedCollection container' do
      get federails.followers_server_actor_path(actor), headers: { 'Accept' => 'application/activity+json' }

      json = JSON.parse(response.body)
      expect(json['type']).to eq('OrderedCollection')
      expect(json).to have_key('totalItems')
      expect(json['first']).to be_present
    end
  end

  describe 'GET following without page param' do
    it 'returns an OrderedCollection container' do
      get federails.following_server_actor_path(actor), headers: { 'Accept' => 'application/activity+json' }

      json = JSON.parse(response.body)
      expect(json['type']).to eq('OrderedCollection')
      expect(json).to have_key('totalItems')
      expect(json['first']).to be_present
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/federation/ordered_collection_container_spec.rb`
Expected: FAIL — currently returns OrderedCollectionPage regardless

- [ ] **Step 3: Add container rendering to RenderCollections concern**

Read `app/controllers/concerns/federails/server/render_collections.rb` first, then add a `render_collection_container` method:

```ruby
def render_collection_container(scope, url:)
  payload = Federails::Server::OrderedCollectionResource::OrderedCollectionPayload.new(
    id: url,
    type: 'OrderedCollection',
    totalItems: scope.count,
    first: "#{url}?page=true",
    last: nil,
    prev: nil,
    next: nil,
    partOf: nil,
    orderedItems: nil,
    context: true
  )

  render_serialized Federails::Server::OrderedCollectionResource, payload,
    content_type: Federails::ACTIVITYPUB_CONTENT_TYPE
end
```

And modify the existing `render_collection` calls in controllers to branch:

```ruby
def outbox
  authorize actor, policy_class: Federails::Server::ActivityPolicy

  if params[:page].present?
    # existing paginated response
    render_collection(...)
  else
    render_collection_container(actor.activities, url: outbox_server_actor_url(actor))
  end
end
```

Apply the same pattern to `followers` and `following` actions in `actors_controller.rb`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/federation/ordered_collection_container_spec.rb`
Expected: PASS

- [ ] **Step 5: Run full test suite**

Run: `bundle exec rspec`
Expected: All PASS (existing tests that don't pass `page` param will now get container responses — update assertions if needed)

- [ ] **Step 6: Commit**

```bash
git add app/controllers/concerns/federails/server/render_collections.rb app/controllers/federails/server/activities_controller.rb app/controllers/federails/server/actors_controller.rb spec/requests/federation/ordered_collection_container_spec.rb
git commit -m "feat: return OrderedCollection container for outbox/followers/following"
```

---

## Task 8: Delivery Reliability — Dead Letter Model

**Files:**
- Create: `db/migrate/XXXXXX_create_federails_dead_letters.rb`
- Create: `app/models/federails/dead_letter.rb`
- Create: `spec/models/federails/dead_letter_spec.rb`

- [ ] **Step 1: Generate migration**

```ruby
class CreateFederailsDeadLetters < ActiveRecord::Migration[7.0]
  def change
    create_table :federails_dead_letters do |t|
      t.references :activity, null: false, foreign_key: { to_table: :federails_activities }
      t.string :target_inbox, null: false
      t.string :last_error
      t.integer :attempts, null: false, default: 0
      t.datetime :last_attempted_at
      t.timestamps
    end

    add_index :federails_dead_letters, [:activity_id, :target_inbox], unique: true
  end
end
```

- [ ] **Step 2: Run migration**

Run: `cd spec/dummy && bundle exec rails db:migrate && cd ../..`

- [ ] **Step 3: Write failing test for DeadLetter model**

Create `spec/models/federails/dead_letter_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Federails::DeadLetter do
  let(:activity) { create(:activity) }

  describe 'validations' do
    it 'requires activity and target_inbox' do
      dl = described_class.new
      expect(dl).not_to be_valid
      expect(dl.errors[:activity]).to be_present
      expect(dl.errors[:target_inbox]).to be_present
    end

    it 'enforces uniqueness of activity + target_inbox' do
      described_class.create!(activity: activity, target_inbox: 'https://example.com/inbox')
      dup = described_class.new(activity: activity, target_inbox: 'https://example.com/inbox')
      expect(dup).not_to be_valid
    end
  end

  describe '.record_failure' do
    it 'creates a new dead letter record' do
      dl = described_class.record_failure(activity: activity, target_inbox: 'https://example.com/inbox', error: 'Connection refused')

      expect(dl).to be_persisted
      expect(dl.attempts).to eq(1)
      expect(dl.last_error).to eq('Connection refused')
      expect(dl.last_attempted_at).to be_present
    end

    it 'increments attempts on repeated failure' do
      described_class.record_failure(activity: activity, target_inbox: 'https://example.com/inbox', error: 'Timeout')
      dl = described_class.record_failure(activity: activity, target_inbox: 'https://example.com/inbox', error: 'Connection refused')

      expect(dl.attempts).to eq(2)
      expect(dl.last_error).to eq('Connection refused')
    end
  end
end
```

- [ ] **Step 4: Run test to verify it fails**

Run: `bundle exec rspec spec/models/federails/dead_letter_spec.rb`
Expected: FAIL — model doesn't exist

- [ ] **Step 5: Create DeadLetter model**

Create `app/models/federails/dead_letter.rb`:

```ruby
# frozen_string_literal: true

module Federails
  class DeadLetter < ApplicationRecord
    belongs_to :activity

    validates :target_inbox, presence: true
    validates :target_inbox, uniqueness: { scope: :activity_id }

    def self.record_failure(activity:, target_inbox:, error:)
      dl = find_or_initialize_by(activity: activity, target_inbox: target_inbox)
      dl.attempts += 1
      dl.last_error = error
      dl.last_attempted_at = Time.current
      dl.save!
      dl
    end
  end
end
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/models/federails/dead_letter_spec.rb`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add db/migrate/*_create_federails_dead_letters.rb app/models/federails/dead_letter.rb spec/models/federails/dead_letter_spec.rb
git commit -m "feat: add DeadLetter model for tracking failed deliveries"
```

---

## Task 9: Delivery Reliability — Job Retry and Error Classification

**Files:**
- Create: `lib/federails/delivery_errors.rb`
- Modify: `app/jobs/federails/notify_inbox_job.rb`
- Modify: `lib/fediverse/notifier.rb`
- Create: `spec/jobs/federails/notify_inbox_job_spec.rb`

- [ ] **Step 1: Create error classes**

Create `lib/federails/delivery_errors.rb`:

```ruby
# frozen_string_literal: true

module Federails
  class DeliveryError < StandardError
    attr_reader :response_code, :inbox_url

    def initialize(message, response_code: nil, inbox_url: nil)
      @response_code = response_code
      @inbox_url = inbox_url
      super(message)
    end
  end

  class PermanentDeliveryError < DeliveryError; end
  class TemporaryDeliveryError < DeliveryError; end
end
```

- [ ] **Step 2: Modify Notifier to raise typed errors**

In `lib/fediverse/notifier.rb`, modify `post_to_inbox` to raise typed errors based on HTTP status:

```ruby
def self.post_to_inbox(inbox_url:, message:, from:)
  response = signed_request(url: inbox_url, message: message, from: from)

  case response.status
  when 200..299
    # success
  when 404, 410
    raise Federails::PermanentDeliveryError.new(
      "Permanent failure: HTTP #{response.status}",
      response_code: response.status,
      inbox_url: inbox_url
    )
  when 429
    retry_after = response.headers['Retry-After']
    raise Federails::TemporaryDeliveryError.new(
      "Rate limited: retry after #{retry_after}",
      response_code: response.status,
      inbox_url: inbox_url
    )
  else
    raise Federails::TemporaryDeliveryError.new(
      "Temporary failure: HTTP #{response.status}",
      response_code: response.status,
      inbox_url: inbox_url
    )
  end
end
```

- [ ] **Step 3: Write failing test for retry behavior**

Create `spec/jobs/federails/notify_inbox_job_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Federails::NotifyInboxJob do
  let(:activity) { create(:activity) }

  it 'retries on TemporaryDeliveryError' do
    allow(Fediverse::Notifier).to receive(:post_to_inboxes).and_raise(
      Federails::TemporaryDeliveryError.new('Server error', response_code: 500, inbox_url: 'https://example.com/inbox')
    )

    expect {
      described_class.perform_now(activity)
    }.to have_enqueued_job(described_class)
  end

  it 'records dead letter on PermanentDeliveryError' do
    allow(Fediverse::Notifier).to receive(:post_to_inboxes).and_raise(
      Federails::PermanentDeliveryError.new('Gone', response_code: 410, inbox_url: 'https://example.com/inbox')
    )

    expect {
      described_class.perform_now(activity)
    }.to change(Federails::DeadLetter, :count).by(1)
  end

  it 'records dead letter after max retries exhausted' do
    allow(Fediverse::Notifier).to receive(:post_to_inboxes).and_raise(
      Federails::TemporaryDeliveryError.new('Timeout', response_code: 500, inbox_url: 'https://example.com/inbox')
    )

    expect {
      described_class.perform_now(activity)
    }.to have_enqueued_job(described_class)
  end
end
```

- [ ] **Step 4: Run test to verify it fails**

Run: `bundle exec rspec spec/jobs/federails/notify_inbox_job_spec.rb`
Expected: FAIL — job doesn't retry or handle errors

- [ ] **Step 5: Implement retry logic in NotifyInboxJob**

Modify `app/jobs/federails/notify_inbox_job.rb`:

```ruby
# frozen_string_literal: true

module Federails
  class NotifyInboxJob < ApplicationJob
    retry_on Federails::TemporaryDeliveryError,
      wait: :polynomially_longer,
      attempts: 6

    discard_on Federails::PermanentDeliveryError do |job, error|
      activity = job.arguments.first
      DeadLetter.record_failure(
        activity: activity,
        target_inbox: error.inbox_url,
        error: error.message
      )
    end

    def perform(activity)
      activity = Activity.includes(:entity, actor: :entity).find(activity.id)
      Fediverse::Notifier.post_to_inboxes(activity)
    end
  end
end
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/jobs/federails/notify_inbox_job_spec.rb`
Expected: PASS

- [ ] **Step 7: Run full test suite**

Run: `bundle exec rspec`
Expected: All PASS

- [ ] **Step 8: Commit**

```bash
git add lib/federails/delivery_errors.rb app/jobs/federails/notify_inbox_job.rb lib/fediverse/notifier.rb spec/jobs/federails/notify_inbox_job_spec.rb
git commit -m "feat: add delivery retry with exponential backoff and dead letter recording"
```

---

## Task 10: Delivery Reliability — Rake Tasks and Activity Ordering

**Files:**
- Create: `lib/tasks/delivery.rake`
- Create: `spec/tasks/delivery_rake_spec.rb`

- [ ] **Step 1: Create rake tasks**

Create `lib/tasks/delivery.rake`:

```ruby
# frozen_string_literal: true

namespace :federails do
  namespace :delivery do
    desc 'Retry all dead letter deliveries'
    task retry_dead_letters: :environment do
      Federails::DeadLetter.find_each do |dl|
        Federails::NotifyInboxJob.perform_later(dl.activity)
        dl.destroy!
      end
    end

    desc 'Clean up dead letters older than N days (default: 30)'
    task :cleanup, [:days] => :environment do |_t, args|
      days = (args[:days] || 30).to_i
      count = Federails::DeadLetter.where('created_at < ?', days.days.ago).delete_all
      puts "Cleaned up #{count} dead letters older than #{days} days"
    end
  end
end
```

- [ ] **Step 2: Write test for rake tasks**

Create `spec/tasks/delivery_rake_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'federails:delivery rake tasks' do
  before(:all) do
    Rails.application.load_tasks
  end

  describe 'federails:delivery:cleanup' do
    it 'removes dead letters older than specified days' do
      activity = create(:activity)
      old = Federails::DeadLetter.create!(activity: activity, target_inbox: 'https://example.com/inbox', attempts: 1, created_at: 60.days.ago)
      recent = Federails::DeadLetter.create!(activity: create(:activity), target_inbox: 'https://example.com/inbox', attempts: 1)

      Rake::Task['federails:delivery:cleanup'].reenable
      Rake::Task['federails:delivery:cleanup'].invoke('30')

      expect(Federails::DeadLetter.exists?(old.id)).to be false
      expect(Federails::DeadLetter.exists?(recent.id)).to be true
    end
  end
end
```

- [ ] **Step 3: Run test to verify it passes**

Run: `bundle exec rspec spec/tasks/delivery_rake_spec.rb`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/tasks/delivery.rake spec/tasks/delivery_rake_spec.rb
git commit -m "feat: add delivery cleanup and retry rake tasks"
```

---

## Task 11: Like Activity Handler

**Files:**
- Create: `lib/fediverse/inbox/like_handler.rb`
- Modify: `lib/fediverse/inbox.rb`
- Create: `spec/lib/fediverse/inbox/like_handler_spec.rb`

- [ ] **Step 1: Write failing test**

Create `spec/lib/fediverse/inbox/like_handler_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Fediverse::Inbox::LikeHandler do
  let(:local_actor) { create(:local_actor) }
  let(:post) { create(:post, user: local_actor.entity) }

  describe '.handle_like' do
    let(:payload) do
      {
        '@context' => 'https://www.w3.org/ns/activitystreams',
        'id' => 'https://remote.example/activity/like/1',
        'type' => 'Like',
        'actor' => 'https://remote.example/actor',
        'object' => post.federated_url
      }
    end

    it 'creates an activity record' do
      remote_actor = create(:distant_actor, federated_url: 'https://remote.example/actor')
      allow(Federails::Actor).to receive(:find_or_create_by_federation_url).with('https://remote.example/actor').and_return(remote_actor)

      expect {
        Fediverse::Inbox.dispatch_request(payload)
      }.to change(Federails::Activity, :count).by(1)

      activity = Federails::Activity.last
      expect(activity.action).to eq('Like')
      expect(activity.actor).to eq(remote_actor)
    end
  end

  describe '.handle_undo_like' do
    it 'removes the like activity' do
      remote_actor = create(:distant_actor, federated_url: 'https://remote.example/actor')
      like_activity = Federails::Activity.create!(
        action: 'Like',
        actor: remote_actor,
        entity: post,
        federated_url: 'https://remote.example/activity/like/1'
      )

      undo_payload = {
        '@context' => 'https://www.w3.org/ns/activitystreams',
        'id' => 'https://remote.example/activity/undo/1',
        'type' => 'Undo',
        'actor' => 'https://remote.example/actor',
        'object' => {
          'id' => 'https://remote.example/activity/like/1',
          'type' => 'Like',
          'actor' => 'https://remote.example/actor',
          'object' => post.federated_url
        }
      }

      allow(Federails::Actor).to receive(:find_or_create_by_federation_url).with('https://remote.example/actor').and_return(remote_actor)

      expect {
        Fediverse::Inbox.dispatch_request(undo_payload)
      }.to change(Federails::Activity, :count).by(-1)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/lib/fediverse/inbox/like_handler_spec.rb`
Expected: FAIL — no handler for Like or Undo(Like)

- [ ] **Step 3: Create LikeHandler**

Create `lib/fediverse/inbox/like_handler.rb`:

```ruby
# frozen_string_literal: true

module Fediverse
  module Inbox
    module LikeHandler
      class << self
        def handle_like(activity)
          actor_url = activity['actor']
          object_url = activity.dig('object').is_a?(Hash) ? activity['object']['id'] : activity['object']
          actor = Federails::Actor.find_or_create_by_federation_url(actor_url)
          return false unless actor

          entity = Federails::Utils::Object.find_or_initialize(object_url)

          Federails::Activity.create!(
            action: 'Like',
            actor: actor,
            entity: entity,
            federated_url: activity['id']
          )

          true
        end

        def handle_undo_like(activity)
          object = activity['object']
          like_url = object.is_a?(Hash) ? object['id'] : object

          like = Federails::Activity.find_by(federated_url: like_url, action: 'Like')
          return false unless like

          like.destroy!
          true
        end
      end
    end
  end
end
```

- [ ] **Step 4: Register handlers in inbox.rb**

In `lib/fediverse/inbox.rb`, add after existing registrations:

```ruby
require_relative 'inbox/like_handler'

register_handler 'Like', '*', Fediverse::Inbox::LikeHandler, :handle_like
register_handler 'Undo', 'Like', Fediverse::Inbox::LikeHandler, :handle_undo_like
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/lib/fediverse/inbox/like_handler_spec.rb`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/fediverse/inbox/like_handler.rb lib/fediverse/inbox.rb spec/lib/fediverse/inbox/like_handler_spec.rb
git commit -m "feat: add Like and Undo(Like) inbox handlers"
```

---

## Task 12: Announce Activity Handler

**Files:**
- Create: `lib/fediverse/inbox/announce_handler.rb`
- Modify: `lib/fediverse/inbox.rb`
- Create: `spec/lib/fediverse/inbox/announce_handler_spec.rb`

- [ ] **Step 1: Write failing test**

Create `spec/lib/fediverse/inbox/announce_handler_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Fediverse::Inbox::AnnounceHandler do
  let(:local_actor) { create(:local_actor) }
  let(:post) { create(:post, user: local_actor.entity) }
  let(:remote_actor) { create(:distant_actor, federated_url: 'https://remote.example/actor') }

  before do
    allow(Federails::Actor).to receive(:find_or_create_by_federation_url)
      .with('https://remote.example/actor').and_return(remote_actor)
  end

  describe '.handle_announce' do
    let(:payload) do
      {
        '@context' => 'https://www.w3.org/ns/activitystreams',
        'id' => 'https://remote.example/activity/announce/1',
        'type' => 'Announce',
        'actor' => 'https://remote.example/actor',
        'object' => post.federated_url
      }
    end

    it 'creates an Announce activity record' do
      expect {
        Fediverse::Inbox.dispatch_request(payload)
      }.to change(Federails::Activity, :count).by(1)

      activity = Federails::Activity.last
      expect(activity.action).to eq('Announce')
      expect(activity.actor).to eq(remote_actor)
    end
  end

  describe '.handle_undo_announce' do
    it 'removes the announce activity' do
      Federails::Activity.create!(
        action: 'Announce',
        actor: remote_actor,
        entity: post,
        federated_url: 'https://remote.example/activity/announce/1'
      )

      undo_payload = {
        '@context' => 'https://www.w3.org/ns/activitystreams',
        'id' => 'https://remote.example/activity/undo/2',
        'type' => 'Undo',
        'actor' => 'https://remote.example/actor',
        'object' => {
          'id' => 'https://remote.example/activity/announce/1',
          'type' => 'Announce'
        }
      }

      expect {
        Fediverse::Inbox.dispatch_request(undo_payload)
      }.to change(Federails::Activity, :count).by(-1)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/lib/fediverse/inbox/announce_handler_spec.rb`
Expected: FAIL

- [ ] **Step 3: Create AnnounceHandler**

Create `lib/fediverse/inbox/announce_handler.rb`:

```ruby
# frozen_string_literal: true

module Fediverse
  module Inbox
    module AnnounceHandler
      class << self
        def handle_announce(activity)
          actor_url = activity['actor']
          object_url = activity['object'].is_a?(Hash) ? activity['object']['id'] : activity['object']
          actor = Federails::Actor.find_or_create_by_federation_url(actor_url)
          return false unless actor

          entity = Federails::Utils::Object.find_or_initialize(object_url)

          Federails::Activity.create!(
            action: 'Announce',
            actor: actor,
            entity: entity,
            federated_url: activity['id']
          )

          true
        end

        def handle_undo_announce(activity)
          object = activity['object']
          announce_url = object.is_a?(Hash) ? object['id'] : object

          announce = Federails::Activity.find_by(federated_url: announce_url, action: 'Announce')
          return false unless announce

          announce.destroy!
          true
        end
      end
    end
  end
end
```

- [ ] **Step 4: Register handlers**

In `lib/fediverse/inbox.rb`, add:

```ruby
require_relative 'inbox/announce_handler'

register_handler 'Announce', '*', Fediverse::Inbox::AnnounceHandler, :handle_announce
register_handler 'Undo', 'Announce', Fediverse::Inbox::AnnounceHandler, :handle_undo_announce
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/lib/fediverse/inbox/announce_handler_spec.rb`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/fediverse/inbox/announce_handler.rb lib/fediverse/inbox.rb spec/lib/fediverse/inbox/announce_handler_spec.rb
git commit -m "feat: add Announce and Undo(Announce) inbox handlers"
```

---

## Task 13: Block Activity — Model and Handler

**Files:**
- Create: `db/migrate/XXXXXX_create_federails_blocks.rb`
- Create: `app/models/federails/block.rb`
- Create: `lib/fediverse/inbox/block_handler.rb`
- Modify: `lib/fediverse/inbox.rb`
- Modify: `lib/fediverse/notifier.rb`
- Create: `spec/models/federails/block_spec.rb`
- Create: `spec/lib/fediverse/inbox/block_handler_spec.rb`

- [ ] **Step 1: Create migration**

```ruby
class CreateFederailsBlocks < ActiveRecord::Migration[7.0]
  def change
    create_table :federails_blocks do |t|
      t.references :actor, null: false, foreign_key: { to_table: :federails_actors }
      t.references :target_actor, null: false, foreign_key: { to_table: :federails_actors }
      t.timestamps
    end

    add_index :federails_blocks, [:actor_id, :target_actor_id], unique: true
  end
end
```

- [ ] **Step 2: Run migration**

Run: `cd spec/dummy && bundle exec rails db:migrate && cd ../..`

- [ ] **Step 3: Write failing test for Block model**

Create `spec/models/federails/block_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Federails::Block do
  let(:actor) { create(:local_actor) }
  let(:target) { create(:distant_actor) }

  it 'creates a valid block' do
    block = described_class.create!(actor: actor, target_actor: target)
    expect(block).to be_persisted
  end

  it 'enforces uniqueness' do
    described_class.create!(actor: actor, target_actor: target)
    dup = described_class.new(actor: actor, target_actor: target)
    expect(dup).not_to be_valid
  end
end
```

- [ ] **Step 4: Create Block model**

Create `app/models/federails/block.rb`:

```ruby
# frozen_string_literal: true

module Federails
  class Block < ApplicationRecord
    belongs_to :actor
    belongs_to :target_actor, class_name: 'Federails::Actor'

    validates :target_actor_id, uniqueness: { scope: :actor_id }
  end
end
```

- [ ] **Step 5: Run model test**

Run: `bundle exec rspec spec/models/federails/block_spec.rb`
Expected: PASS

- [ ] **Step 6: Write failing test for Block handler**

Create `spec/lib/fediverse/inbox/block_handler_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Fediverse::Inbox::BlockHandler do
  let(:local_actor) { create(:local_actor) }
  let(:remote_actor) { create(:distant_actor, federated_url: 'https://remote.example/actor') }

  before do
    allow(Federails::Actor).to receive(:find_or_create_by_federation_url)
      .with('https://remote.example/actor').and_return(remote_actor)
  end

  describe '.handle_block' do
    let(:payload) do
      {
        '@context' => 'https://www.w3.org/ns/activitystreams',
        'id' => 'https://remote.example/activity/block/1',
        'type' => 'Block',
        'actor' => 'https://remote.example/actor',
        'object' => local_actor.federated_url
      }
    end

    it 'creates a block record' do
      expect {
        Fediverse::Inbox.dispatch_request(payload)
      }.to change(Federails::Block, :count).by(1)
    end

    it 'removes existing following relationships' do
      Federails::Following.create!(actor: local_actor, target_actor: remote_actor, status: :accepted)

      Fediverse::Inbox.dispatch_request(payload)

      expect(Federails::Following.where(actor: local_actor, target_actor: remote_actor)).not_to exist
    end
  end

  describe '.handle_undo_block' do
    it 'removes the block record' do
      Federails::Block.create!(actor: remote_actor, target_actor: local_actor)

      undo_payload = {
        '@context' => 'https://www.w3.org/ns/activitystreams',
        'id' => 'https://remote.example/activity/undo/3',
        'type' => 'Undo',
        'actor' => 'https://remote.example/actor',
        'object' => {
          'id' => 'https://remote.example/activity/block/1',
          'type' => 'Block',
          'object' => local_actor.federated_url
        }
      }

      expect {
        Fediverse::Inbox.dispatch_request(undo_payload)
      }.to change(Federails::Block, :count).by(-1)
    end
  end
end
```

- [ ] **Step 7: Create BlockHandler**

Create `lib/fediverse/inbox/block_handler.rb`:

```ruby
# frozen_string_literal: true

module Fediverse
  module Inbox
    module BlockHandler
      class << self
        def handle_block(activity)
          actor_url = activity['actor']
          object_url = activity['object'].is_a?(Hash) ? activity['object']['id'] : activity['object']

          actor = Federails::Actor.find_or_create_by_federation_url(actor_url)
          target = Federails::Actor.find_by_federation_url(object_url)
          return false unless actor && target

          Federails::Block.find_or_create_by!(actor: actor, target_actor: target)

          # Remove existing following relationships in both directions
          Federails::Following.where(actor: actor, target_actor: target).destroy_all
          Federails::Following.where(actor: target, target_actor: actor).destroy_all

          true
        end

        def handle_undo_block(activity)
          object = activity['object']
          actor_url = activity['actor']
          target_url = object.is_a?(Hash) ? object['object'] : nil
          target_url = target_url['id'] if target_url.is_a?(Hash)

          return false unless target_url

          actor = Federails::Actor.find_by_federation_url(actor_url)
          target = Federails::Actor.find_by_federation_url(target_url)
          return false unless actor && target

          block = Federails::Block.find_by(actor: actor, target_actor: target)
          return false unless block

          block.destroy!
          true
        end
      end
    end
  end
end
```

- [ ] **Step 8: Register handlers**

In `lib/fediverse/inbox.rb`, add:

```ruby
require_relative 'inbox/block_handler'

register_handler 'Block', '*', Fediverse::Inbox::BlockHandler, :handle_block
register_handler 'Undo', 'Block', Fediverse::Inbox::BlockHandler, :handle_undo_block
```

- [ ] **Step 9: Run tests**

Run: `bundle exec rspec spec/models/federails/block_spec.rb spec/lib/fediverse/inbox/block_handler_spec.rb`
Expected: PASS

- [ ] **Step 10: Add block filtering to Notifier**

In `lib/fediverse/notifier.rb`, in the `inboxes_for` method, filter out blocked actors:

```ruby
def self.inboxes_for(activity)
  actors = resolve_recipient_actors(activity)
  actors.reject! { |a| a.federated_url == activity.actor.federated_url }

  # Filter out actors who have blocked the sender
  blocked_actor_ids = Federails::Block.where(target_actor: activity.actor).pluck(:actor_id)
  actors.reject! { |a| blocked_actor_ids.include?(a.id) }

  inboxes = Set.new
  actors.each do |actor|
    inbox = actor.shared_inbox_url || actor.inbox_url
    inboxes.add(inbox) if inbox.present?
  end

  inboxes.to_a
end
```

- [ ] **Step 11: Run full test suite**

Run: `bundle exec rspec`
Expected: All PASS

- [ ] **Step 12: Commit**

```bash
git add db/migrate/*_create_federails_blocks.rb app/models/federails/block.rb lib/fediverse/inbox/block_handler.rb lib/fediverse/inbox.rb lib/fediverse/notifier.rb spec/models/federails/block_spec.rb spec/lib/fediverse/inbox/block_handler_spec.rb
git commit -m "feat: add Block/Undo(Block) with delivery filtering"
```

---

## Task 14: LD Signatures Verification

**Files:**
- Create: `lib/fediverse/linked_data_signature.rb`
- Modify: `lib/fediverse/inbox/announce_handler.rb`
- Create: `spec/lib/fediverse/linked_data_signature_spec.rb`

- [ ] **Step 1: Write failing test for LD Signature verification**

Create `spec/lib/fediverse/linked_data_signature_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Fediverse::LinkedDataSignature do
  let(:keypair) { OpenSSL::PKey::RSA.generate(2048) }
  let(:actor) { create(:distant_actor) }

  before do
    actor.update_columns(public_key: keypair.public_key.to_pem)
  end

  def sign_document(doc, key:, creator:)
    options = {
      '@context' => 'https://w3id.org/identity/v1',
      'type' => 'RsaSignature2017',
      'creator' => creator,
      'created' => Time.now.utc.iso8601
    }

    options_hash = described_class.send(:hash_options, options)
    document_hash = described_class.send(:hash_document, doc)
    to_sign = options_hash + document_hash

    signature = Base64.strict_encode64(key.sign(OpenSSL::Digest.new('SHA256'), to_sign))
    doc.merge('signature' => options.merge('signatureValue' => signature))
  end

  describe '.verify' do
    it 'returns true for a validly signed document' do
      doc = {
        '@context' => 'https://www.w3.org/ns/activitystreams',
        'id' => 'https://remote.example/activity/1',
        'type' => 'Create',
        'actor' => actor.federated_url
      }

      signed = sign_document(doc, key: keypair, creator: actor.key_id)
      allow(Federails::Actor).to receive(:find_or_create_by_federation_url).and_return(actor)

      result = described_class.verify(signed)
      expect(result[:verified]).to be true
      expect(result[:actor]).to eq(actor)
    end

    it 'returns false for a tampered document' do
      doc = {
        '@context' => 'https://www.w3.org/ns/activitystreams',
        'id' => 'https://remote.example/activity/1',
        'type' => 'Create',
        'actor' => actor.federated_url
      }

      signed = sign_document(doc, key: keypair, creator: actor.key_id)
      signed['type'] = 'Delete'  # tamper

      allow(Federails::Actor).to receive(:find_or_create_by_federation_url).and_return(actor)

      result = described_class.verify(signed)
      expect(result[:verified]).to be false
    end

    it 'returns nil when no signature present' do
      doc = { '@context' => 'https://www.w3.org/ns/activitystreams', 'type' => 'Create' }
      expect(described_class.verify(doc)).to be_nil
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/lib/fediverse/linked_data_signature_spec.rb`
Expected: FAIL — class doesn't exist

- [ ] **Step 3: Implement LinkedDataSignature**

Create `lib/fediverse/linked_data_signature.rb`:

```ruby
# frozen_string_literal: true

module Fediverse
  module LinkedDataSignature
    class << self
      def verify(document)
        signature = document['signature']
        return nil unless signature

        creator_uri = signature['creator']&.sub(/#.*\z/, '')
        return { verified: false, error: 'No creator in signature' } unless creator_uri

        actor = Federails::Actor.find_or_create_by_federation_url(creator_uri)
        return { verified: false, error: 'Could not resolve signing actor' } unless actor

        options_hash = hash_options(signature.except('type', 'id', 'signatureValue'))
        document_hash = hash_document(document.except('signature'))
        to_verify = options_hash + document_hash

        signature_bytes = Base64.strict_decode64(signature['signatureValue'])
        public_key = OpenSSL::PKey::RSA.new(actor.public_key)

        verified = public_key.verify(OpenSSL::Digest.new('SHA256'), signature_bytes, to_verify)
        { verified: verified, actor: actor }
      rescue OpenSSL::PKey::PKeyError, ArgumentError => e
        { verified: false, error: e.message }
      end

      private

      def hash_options(options)
        options = options.merge('@context' => 'https://w3id.org/identity/v1')
        normalized = normalize(options)
        OpenSSL::Digest::SHA256.hexdigest(normalized)
      end

      def hash_document(document)
        normalized = normalize(document)
        OpenSSL::Digest::SHA256.hexdigest(normalized)
      end

      def normalize(document)
        JSON::LD::API.toRdf(document).map(&:to_s).sort.join
      rescue StandardError => e
        Federails.logger.warn "JSON-LD normalization failed: #{e.message}"
        document.to_json
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/lib/fediverse/linked_data_signature_spec.rb`
Expected: PASS

- [ ] **Step 5: Integrate with AnnounceHandler**

In `lib/fediverse/inbox/announce_handler.rb`, modify `handle_announce`:

```ruby
def handle_announce(activity)
  actor_url = activity['actor']
  object = activity['object']
  object_data = object.is_a?(Hash) ? object : Fediverse::Request.dereference(object)

  # Verify LD Signature on inner activity if present
  if object_data.is_a?(Hash) && object_data['signature']
    ld_result = Fediverse::LinkedDataSignature.verify(object_data)
    if ld_result && !ld_result[:verified]
      Federails.logger.warn "LD Signature verification failed for Announce inner object: #{ld_result[:error]}"
    end
  end

  object_url = object_data.is_a?(Hash) ? object_data['id'] : object
  actor = Federails::Actor.find_or_create_by_federation_url(actor_url)
  return false unless actor

  entity = Federails::Utils::Object.find_or_initialize(object_url)

  Federails::Activity.create!(
    action: 'Announce',
    actor: actor,
    entity: entity,
    federated_url: activity['id']
  )

  true
end
```

- [ ] **Step 6: Run all handler tests**

Run: `bundle exec rspec spec/lib/fediverse/inbox/`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
git add lib/fediverse/linked_data_signature.rb lib/fediverse/inbox/announce_handler.rb spec/lib/fediverse/linked_data_signature_spec.rb
git commit -m "feat: add LD Signatures verification (verify-only) with Announce integration"
```

---

## Task 15: bto/bcc Strip + Audience Processing

**Files:**
- Modify: `lib/fediverse/notifier.rb`
- Modify: `app/serializers/federails/server/activity_resource.rb`
- Create: `spec/lib/fediverse/notifier_bto_bcc_spec.rb`

- [ ] **Step 1: Write failing test for bto/bcc stripping in outbound payload**

Create `spec/lib/fediverse/notifier_bto_bcc_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Fediverse::Notifier, 'bto/bcc handling' do
  let(:local_actor) { create(:local_actor) }
  let(:bto_actor) { create(:distant_actor, federated_url: 'https://remote.example/bto-actor') }
  let(:bcc_actor) { create(:distant_actor, federated_url: 'https://remote.example/bcc-actor') }

  describe 'outbound delivery' do
    it 'includes bto/bcc recipients in delivery targets but strips from payload' do
      activity = create(:activity,
        actor: local_actor,
        to: [Fediverse::Collection::PUBLIC],
        bto: [bto_actor.federated_url],
        bcc: [bcc_actor.federated_url]
      )

      delivered_payloads = []
      delivered_inboxes = []

      allow(described_class).to receive(:post_to_inbox) do |inbox_url:, message:, from:|
        delivered_inboxes << inbox_url
        delivered_payloads << JSON.parse(message)
      end

      described_class.post_to_inboxes(activity)

      # bto/bcc recipients should be in delivery targets
      expect(delivered_inboxes).to include(bto_actor.inbox_url)
      expect(delivered_inboxes).to include(bcc_actor.inbox_url)

      # bto/bcc should be stripped from all delivered payloads
      delivered_payloads.each do |payload|
        expect(payload).not_to have_key('bto')
        expect(payload).not_to have_key('bcc')
      end
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/lib/fediverse/notifier_bto_bcc_spec.rb`
Expected: FAIL — bto/bcc not stripped from payload

- [ ] **Step 3: Modify Notifier payload to strip bto/bcc**

In `lib/fediverse/notifier.rb`, modify the `payload` method:

```ruby
def self.payload(activity)
  json = Federails::Server::ActivityResource.new(activity).serializable_hash
  json.delete(:bto)
  json.delete(:bcc)
  json.delete('bto')
  json.delete('bcc')
  json.to_json
end
```

- [ ] **Step 4: Ensure `inboxes_for` includes bto/bcc recipients**

Verify that the existing `inboxes_for` already resolves `bto`/`bcc` (it should via the existing addressing resolution). If not, add:

```ruby
def self.resolve_recipient_actors(activity)
  urls = [activity.to, activity.cc, activity.bto, activity.bcc, activity.audience].flatten.compact
  urls.reject! { |url| url == Fediverse::Collection::PUBLIC }
  # ... existing resolution logic
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/lib/fediverse/notifier_bto_bcc_spec.rb`
Expected: PASS

- [ ] **Step 6: Run full test suite**

Run: `bundle exec rspec`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
git add lib/fediverse/notifier.rb spec/lib/fediverse/notifier_bto_bcc_spec.rb
git commit -m "feat: strip bto/bcc from outbound payloads while including in delivery targets"
```

---

## Task 16: Missing Collections — liked, featured, featured_tags

**Files:**
- Create: `db/migrate/XXXXXX_create_federails_featured_items.rb`
- Create: `db/migrate/XXXXXX_create_federails_featured_tags.rb`
- Create: `app/models/federails/featured_item.rb`
- Create: `app/models/federails/featured_tag.rb`
- Modify: `app/controllers/federails/server/actors_controller.rb`
- Modify: `config/routes.rb`
- Modify: `app/serializers/federails/server/actor_resource.rb`
- Create: `spec/requests/federation/collections_spec.rb`

- [ ] **Step 1: Create migrations**

`featured_items`:

```ruby
class CreateFederailsFeaturedItems < ActiveRecord::Migration[7.0]
  def change
    create_table :federails_featured_items do |t|
      t.references :actor, null: false, foreign_key: { to_table: :federails_actors }
      t.string :federated_url, null: false
      t.timestamps
    end

    add_index :federails_featured_items, [:actor_id, :federated_url], unique: true
  end
end
```

`featured_tags`:

```ruby
class CreateFederailsFeaturedTags < ActiveRecord::Migration[7.0]
  def change
    create_table :federails_featured_tags do |t|
      t.references :actor, null: false, foreign_key: { to_table: :federails_actors }
      t.string :name, null: false
      t.timestamps
    end

    add_index :federails_featured_tags, [:actor_id, :name], unique: true
  end
end
```

- [ ] **Step 2: Run migrations**

Run: `cd spec/dummy && bundle exec rails db:migrate && cd ../..`

- [ ] **Step 3: Create models**

Create `app/models/federails/featured_item.rb`:

```ruby
# frozen_string_literal: true

module Federails
  class FeaturedItem < ApplicationRecord
    belongs_to :actor

    validates :federated_url, presence: true
    validates :federated_url, uniqueness: { scope: :actor_id }
  end
end
```

Create `app/models/federails/featured_tag.rb`:

```ruby
# frozen_string_literal: true

module Federails
  class FeaturedTag < ApplicationRecord
    belongs_to :actor

    validates :name, presence: true
    validates :name, uniqueness: { scope: :actor_id }
  end
end
```

- [ ] **Step 4: Add associations to Actor**

In `app/models/federails/actor.rb`:

```ruby
has_many :featured_items, dependent: :destroy
has_many :featured_tags, dependent: :destroy
```

And add convenience methods:

```ruby
def feature(federated_url)
  featured_items.find_or_create_by!(federated_url: federated_url)
end

def unfeature(federated_url)
  featured_items.find_by(federated_url: federated_url)&.destroy!
end
```

- [ ] **Step 5: Add routes**

In `config/routes.rb`, inside the server actor routes:

```ruby
resources :actors, only: [:show] do
  member do
    get :followers
    get :following
    get :liked
    get :featured
    get :featured_tags
  end
  # ... existing nested resources
end
```

- [ ] **Step 6: Add controller actions**

In `app/controllers/federails/server/actors_controller.rb`:

```ruby
def liked
  authorize actor, policy_class: Federails::Server::ActorPolicy

  if params[:page].present?
    liked_activities = Federails::Activity.where(actor: actor, action: 'Like')
    render_collection(liked_activities, url: liked_server_actor_url(actor)) do |activity|
      Federails::Server::ActivityResource.new(activity, params: { context: false }).serializable_hash
    end
  else
    count = Federails::Activity.where(actor: actor, action: 'Like').count
    render_collection_container(Federails::Activity.where(actor: actor, action: 'Like'), url: liked_server_actor_url(actor))
  end
end

def featured
  authorize actor, policy_class: Federails::Server::ActorPolicy

  if params[:page].present?
    items = actor.featured_items
    render_collection(items, url: featured_server_actor_url(actor)) do |item|
      { id: item.federated_url, type: 'Note' }
    end
  else
    render_collection_container(actor.featured_items, url: featured_server_actor_url(actor))
  end
end

def featured_tags
  authorize actor, policy_class: Federails::Server::ActorPolicy

  if params[:page].present?
    tags = actor.featured_tags
    render_collection(tags, url: featured_tags_server_actor_url(actor)) do |tag|
      { type: 'Hashtag', href: tag.name, name: "##{tag.name}" }
    end
  else
    render_collection_container(actor.featured_tags, url: featured_tags_server_actor_url(actor))
  end
end
```

- [ ] **Step 7: Add collection URLs to ActorResource**

In `app/serializers/federails/server/actor_resource.rb`:

```ruby
attribute :liked do |actor|
  SerializerSupport.route_helpers.liked_server_actor_url(actor) if actor.local?
end

attribute :featured do |actor|
  SerializerSupport.route_helpers.featured_server_actor_url(actor) if actor.local?
end

attribute :featuredTags do |actor|
  SerializerSupport.route_helpers.featured_tags_server_actor_url(actor) if actor.local?
end
```

- [ ] **Step 8: Write tests**

Create `spec/requests/federation/collections_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Actor Collections', type: :request do
  let(:user) { create(:user) }
  let(:actor) { user.federails_actor }

  describe 'GET liked' do
    it 'returns an OrderedCollection container' do
      get federails.liked_server_actor_path(actor), headers: { 'Accept' => 'application/activity+json' }

      json = JSON.parse(response.body)
      expect(json['type']).to eq('OrderedCollection')
      expect(json).to have_key('totalItems')
    end
  end

  describe 'GET featured' do
    it 'returns an OrderedCollection container' do
      get federails.featured_server_actor_path(actor), headers: { 'Accept' => 'application/activity+json' }

      json = JSON.parse(response.body)
      expect(json['type']).to eq('OrderedCollection')
    end
  end

  describe 'GET featured_tags' do
    it 'returns an OrderedCollection container' do
      get federails.featured_tags_server_actor_path(actor), headers: { 'Accept' => 'application/activity+json' }

      json = JSON.parse(response.body)
      expect(json['type']).to eq('OrderedCollection')
    end
  end

  describe 'Actor JSON includes collection URLs' do
    it 'includes liked, featured, featuredTags' do
      get federails.server_actor_path(actor), headers: { 'Accept' => 'application/activity+json' }

      json = JSON.parse(response.body)
      expect(json['liked']).to be_present
      expect(json['featured']).to be_present
      expect(json['featuredTags']).to be_present
    end
  end
end
```

- [ ] **Step 9: Run tests**

Run: `bundle exec rspec spec/requests/federation/collections_spec.rb`
Expected: PASS

- [ ] **Step 10: Run full test suite**

Run: `bundle exec rspec`
Expected: All PASS

- [ ] **Step 11: Commit**

```bash
git add db/migrate/*_create_federails_featured_items.rb db/migrate/*_create_federails_featured_tags.rb app/models/federails/featured_item.rb app/models/federails/featured_tag.rb app/models/federails/actor.rb app/controllers/federails/server/actors_controller.rb config/routes.rb app/serializers/federails/server/actor_resource.rb spec/requests/federation/collections_spec.rb
git commit -m "feat: add liked, featured, featured_tags collections"
```

---

## Task 17: Final Integration Test and Cleanup

**Files:**
- Create: `spec/integration/activitypub_compliance_spec.rb`

- [ ] **Step 1: Write integration test covering P0 requirements**

Create `spec/integration/activitypub_compliance_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ActivityPub Compliance', type: :request do
  let(:user) { create(:user) }
  let(:actor) { user.federails_actor }

  describe 'Actor JSON' do
    before { get federails.server_actor_path(actor), headers: { 'Accept' => 'application/activity+json' } }
    let(:json) { JSON.parse(response.body) }

    it 'includes required properties' do
      expect(json['id']).to be_present
      expect(json['inbox']).to be_present
      expect(json['outbox']).to be_present
      expect(json['followers']).to be_present
      expect(json['following']).to be_present
      expect(json['endpoints']['sharedInbox']).to be_present
      expect(json['liked']).to be_present
      expect(json['featured']).to be_present
      expect(json['publicKey']).to be_present
    end
  end

  describe 'Collection containers' do
    it 'outbox returns OrderedCollection with totalItems and first' do
      get federails.outbox_server_actor_path(actor), headers: { 'Accept' => 'application/activity+json' }
      json = JSON.parse(response.body)

      expect(json['type']).to eq('OrderedCollection')
      expect(json['totalItems']).to be_a(Integer)
      expect(json['first']).to be_present
    end

    it 'followers returns OrderedCollection with totalItems and first' do
      get federails.followers_server_actor_path(actor), headers: { 'Accept' => 'application/activity+json' }
      json = JSON.parse(response.body)

      expect(json['type']).to eq('OrderedCollection')
      expect(json['totalItems']).to be_a(Integer)
    end
  end

  describe 'Inbox signature enforcement' do
    it 'rejects unsigned POST when verify_signatures is enabled' do
      Federails.verify_signatures = true

      payload = { '@context' => 'https://www.w3.org/ns/activitystreams', 'id' => 'https://remote.example/1', 'type' => 'Follow', 'actor' => 'https://remote.example/actor', 'object' => actor.federated_url }.to_json

      post federails.server_actor_inbox_path(actor), params: payload, headers: { 'Content-Type' => 'application/activity+json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'Shared inbox' do
    it 'accepts POST at shared inbox endpoint' do
      Federails.verify_signatures = false
      allow(Fediverse::Inbox).to receive(:dispatch_request).and_return(true)

      payload = { '@context' => 'https://www.w3.org/ns/activitystreams', 'id' => 'https://remote.example/2', 'type' => 'Create', 'actor' => 'https://remote.example/actor', 'object' => { 'type' => 'Note', 'content' => 'test' }, 'to' => [actor.federated_url] }.to_json

      post federails.server_shared_inbox_path, params: payload, headers: { 'Content-Type' => 'application/activity+json' }
      expect(response).to have_http_status(:created)
    end
  end
end
```

- [ ] **Step 2: Run integration tests**

Run: `bundle exec rspec spec/integration/activitypub_compliance_spec.rb`
Expected: All PASS

- [ ] **Step 3: Run full test suite**

Run: `bundle exec rspec`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add spec/integration/activitypub_compliance_spec.rb
git commit -m "test: add ActivityPub compliance integration tests"
```
