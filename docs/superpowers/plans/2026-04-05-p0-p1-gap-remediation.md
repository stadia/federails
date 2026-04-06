# P0/P1 갭 수정 구현 플랜

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** P0/P1 로드맵 평가에서 발견된 미충족 갭 5건을 수정하여 스펙 수용 조건을 충족한다.

**Architecture:** 기존 코드를 최소한으로 수정. SharedInboxController에 로컬 수신자 검증 추가, NotifyInboxJob 백오프 스케줄 교체, AnnounceHandler에 리모트 fetch와 LD Signature 검증 연동, Inbox의 record_processed_activity에서 bto/bcc strip.

**Tech Stack:** Ruby on Rails engine, RSpec, FactoryBot

---

## File Map

### Task 1: G1 — Shared Inbox 로컬 수신자 검증
- Modify: `app/controllers/federails/server/shared_inbox_controller.rb`
- Modify: `spec/requests/federation/shared_inbox_spec.rb`

### Task 2: G2 — Delivery Reliability 백오프 스케줄 보정
- Modify: `app/jobs/federails/notify_inbox_job.rb`
- Modify: `spec/jobs/federails/notify_inbox_job_spec.rb`

### Task 3: G3 — Announce Object 조건부 Fetch/캐시
- Modify: `lib/fediverse/inbox/announce_handler.rb`
- Modify: `spec/lib/fediverse/inbox/announce_handler_spec.rb`

### Task 4: G4 — LD Signatures → Announce 연동
- Modify: `lib/fediverse/inbox/announce_handler.rb`
- Modify: `spec/lib/fediverse/inbox/announce_handler_spec.rb`

### Task 5: G5 — Inbound bto/bcc 방어적 무시
- Modify: `lib/fediverse/inbox.rb`
- Modify: `spec/lib/fediverse/inbox_spec.rb`

---

## Task 1: G1 — Shared Inbox 로컬 수신자 검증

**Files:**
- Modify: `app/controllers/federails/server/shared_inbox_controller.rb`
- Modify: `spec/requests/federation/shared_inbox_spec.rb`

- [ ] **Step 1: Write failing test — activity with no local recipients returns 422**

In `spec/requests/federation/shared_inbox_spec.rb`, add inside the `describe 'POST /federation/inbox'` block:

```ruby
context 'when to/cc contains no local actors' do
  let(:payload) do
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id'       => 'https://remote.example/activity/2',
      'type'     => 'Create',
      'actor'    => 'https://remote.example/actor',
      'object'   => { 'type' => 'Note', 'id' => 'https://remote.example/note/1', 'content' => 'hello' },
      'to'       => ['https://other-remote.example/actor'],
      'cc'       => [],
    }.to_json
  end

  it 'returns 422' do
    post federails.server_shared_inbox_path, params: payload, headers: { 'Content-Type' => 'application/activity+json' }

    expect(response).to have_http_status(:unprocessable_entity).or have_http_status(:unprocessable_content)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/federation/shared_inbox_spec.rb -e 'no local actors'`
Expected: FAIL — currently returns 201 or processes the activity

- [ ] **Step 3: Write failing test — activity with local recipient in to/cc is accepted**

In `spec/requests/federation/shared_inbox_spec.rb`, add inside the `describe 'POST /federation/inbox'` block:

```ruby
context 'when to/cc contains a local actor' do
  let(:payload) do
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id'       => 'https://remote.example/activity/3',
      'type'     => 'Follow',
      'actor'    => 'https://remote.example/actor',
      'object'   => actor.federated_url,
      'to'       => [actor.federated_url],
      'cc'       => [],
    }.to_json
  end

  it 'accepts with 201' do
    allow(Fediverse::Inbox).to receive(:dispatch_request).and_return(true)
    allow(Fediverse::Inbox).to receive(:maybe_forward)

    post federails.server_shared_inbox_path, params: payload, headers: { 'Content-Type' => 'application/activity+json' }

    expect(response).to have_http_status(:created)
  end
end
```

- [ ] **Step 4: Run tests to verify new test passes (existing behavior) and no-local test fails**

Run: `bundle exec rspec spec/requests/federation/shared_inbox_spec.rb`
Expected: 'no local actors' test FAILS, 'local actor' test PASSES

- [ ] **Step 5: Implement local recipient resolution in SharedInboxController**

Replace the entire `create` method and add `resolve_local_recipients` private method in `app/controllers/federails/server/shared_inbox_controller.rb`:

```ruby
# POST /federation/inbox
def create
  payload = payload_from_params
  return head Federails::Utils::ResponseCodes::UNPROCESSABLE_CONTENT unless payload
  return head :unauthorized unless actor_match?(payload)

  local_recipients = resolve_local_recipients(payload)
  if local_recipients.empty?
    Federails.logger.info { "[SharedInbox] No local recipients for activity #{payload['id']}" }
    return head Federails::Utils::ResponseCodes::UNPROCESSABLE_CONTENT
  end

  Federails.logger.info { "[SharedInbox] Local recipients: #{local_recipients.map(&:federated_url).join(', ')}" }

  result = Fediverse::Inbox.dispatch_request(payload)
  Federails.logger.info { "[SharedInbox] dispatch_request result: #{result.inspect} for activity #{payload['id']}" }

  case result
  when true
    Fediverse::Inbox.maybe_forward(payload)
    head :created
  when :duplicate
    head :ok
  else
    head Federails::Utils::ResponseCodes::UNPROCESSABLE_CONTENT
  end
end
```

Add the private method:

```ruby
def resolve_local_recipients(payload)
  urls = [payload['to'], payload['cc']].flatten.compact.uniq
  urls.filter_map do |url|
    route = Federails::Utils::Host.local_route(url)
    next unless route && route[:controller] == 'federails/server/actors'

    Federails::Actor.find_param(route[:id])
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
```

- [ ] **Step 6: Run all shared inbox tests**

Run: `bundle exec rspec spec/requests/federation/shared_inbox_spec.rb`
Expected: ALL PASS

- [ ] **Step 7: Commit**

```bash
git add app/controllers/federails/server/shared_inbox_controller.rb spec/requests/federation/shared_inbox_spec.rb
git commit -m "feat: shared inbox에서 to/cc 로컬 수신자 검증 추가

로컬 수신자가 없는 activity를 422로 거부하고,
resolve된 로컬 수신자를 로깅한다.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 2: G2 — Delivery Reliability 백오프 스케줄 보정

**Files:**
- Modify: `app/jobs/federails/notify_inbox_job.rb`
- Modify: `spec/jobs/federails/notify_inbox_job_spec.rb`

- [ ] **Step 1: Write failing test — verify fixed backoff schedule**

In `spec/jobs/federails/notify_inbox_job_spec.rb`, add inside the `context 'when a TemporaryDeliveryError is raised'` block:

```ruby
it 'uses fixed backoff schedule: 30s, 1m, 5m, 30m, 2h, 12h' do
  error = Federails::TemporaryDeliveryError.new('Server error', response_code: 500, inbox_url: inbox_url)
  allow(Fediverse::Notifier).to receive(:deliver_to_inbox).and_raise(error)

  expected_waits = [30, 60, 300, 1800, 7200, 43200]

  expected_waits.each_with_index do |wait, index|
    job = described_class.new(activity, inbox_url)
    # Simulate execution count (1-based)
    allow(job).to receive(:executions).and_return(index + 1)

    expect(job).to receive(:retry_job).with(hash_including(wait: wait))

    job.perform(activity, inbox_url)
  rescue Federails::TemporaryDeliveryError
    # 6회 초과시 raise됨 — 여기선 해당 안 됨
  end
end

it 'raises after 6 retries' do
  error = Federails::TemporaryDeliveryError.new('Server error', response_code: 500, inbox_url: inbox_url)
  allow(Fediverse::Notifier).to receive(:deliver_to_inbox).and_raise(error)

  job = described_class.new(activity, inbox_url)
  allow(job).to receive(:executions).and_return(7)

  expect { job.perform(activity, inbox_url) }.to raise_error(Federails::TemporaryDeliveryError)
end

it 'uses Retry-After value when present for 429 responses' do
  error = Federails::TemporaryDeliveryError.new('Rate limited', response_code: 429, inbox_url: inbox_url, retry_after: 120)
  allow(Fediverse::Notifier).to receive(:deliver_to_inbox).and_raise(error)

  job = described_class.new(activity, inbox_url)
  allow(job).to receive(:executions).and_return(1)

  expect(job).to receive(:retry_job).with(hash_including(wait: 120))

  job.perform(activity, inbox_url)
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/jobs/federails/notify_inbox_job_spec.rb`
Expected: FAIL — current implementation uses `(executions**3)+5` instead of fixed schedule

- [ ] **Step 3: Implement fixed backoff schedule**

Replace the entire `app/jobs/federails/notify_inbox_job.rb`:

```ruby
require 'fediverse/notifier'

module Federails
  class NotifyInboxJob < ApplicationJob
    BACKOFF_SCHEDULE = [30, 60, 300, 1800, 7200, 43200].freeze

    rescue_from Federails::TemporaryDeliveryError do |exception|
      current_attempt = executions

      if current_attempt <= BACKOFF_SCHEDULE.length
        wait = if exception.respond_to?(:retry_after) && exception.retry_after.to_i.positive?
                 exception.retry_after
               else
                 BACKOFF_SCHEDULE[current_attempt - 1]
               end

        retry_job wait: wait, error: exception
      else
        raise exception
      end
    end
    discard_on Federails::PermanentDeliveryError

    def perform(activity, inbox_url = nil)
      activity = Activity.includes(:entity, actor: :entity).find(activity.id)

      if inbox_url
        Fediverse::Notifier.deliver_to_inbox(activity, inbox_url)
      else
        Fediverse::Notifier.enqueue_deliveries(activity)
      end
    end
  end
end
```

- [ ] **Step 4: Run tests**

Run: `bundle exec rspec spec/jobs/federails/notify_inbox_job_spec.rb`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add app/jobs/federails/notify_inbox_job.rb spec/jobs/federails/notify_inbox_job_spec.rb
git commit -m "fix: NotifyInboxJob 백오프 스케줄을 고정 값으로 교체

(n³)+5 기반에서 30s, 1m, 5m, 30m, 2h, 12h 고정 스케줄로 변경.
429 Retry-After 값 우선 사용은 유지.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 3: G3 — Announce Object 조건부 Fetch/캐시

**Files:**
- Modify: `lib/fediverse/inbox/announce_handler.rb`
- Modify: `spec/lib/fediverse/inbox/announce_handler_spec.rb`

- [ ] **Step 1: Write failing test — remote fetch when local entity not found**

In `spec/lib/fediverse/inbox/announce_handler_spec.rb`, add inside the `describe '.handle_announce'` block:

```ruby
context 'when object is not found locally' do
  let(:remote_object_url) { 'https://remote.example/note/42' }
  let(:fetched_json) do
    { 'type' => 'Note', 'id' => remote_object_url, 'content' => 'hello from remote' }
  end
  let(:activity) { { 'type' => 'Announce', 'actor' => 'https://remote.example/actor', 'object' => remote_object_url } }

  it 'fetches the object from remote and resolves the entity' do
    allow(Federails::Utils::Object).to receive(:find_or_initialize).with(remote_object_url).and_return(nil)
    allow(Fediverse::Request).to receive(:dereference).with(remote_object_url).and_return(fetched_json)
    allow(Federails::Utils::Object).to receive(:find_or_initialize).with(fetched_json).and_return(entity)
    allow(entity).to receive(:run_callbacks).with(:on_federails_announce_received).and_yield

    expect(described_class.handle_announce(activity)).to be true
    expect(Fediverse::Request).to have_received(:dereference).with(remote_object_url)
  end
end

context 'when remote fetch fails' do
  let(:remote_object_url) { 'https://remote.example/note/gone' }
  let(:activity) { { 'type' => 'Announce', 'actor' => 'https://remote.example/actor', 'object' => remote_object_url } }

  it 'returns true without raising' do
    allow(Federails::Utils::Object).to receive(:find_or_initialize).with(remote_object_url).and_return(nil)
    allow(Fediverse::Request).to receive(:dereference).with(remote_object_url).and_return(nil)

    expect(described_class.handle_announce(activity)).to be true
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/lib/fediverse/inbox/announce_handler_spec.rb -e 'not found locally'`
Expected: FAIL — current code does not call `Fediverse::Request.dereference`

- [ ] **Step 3: Implement remote fetch in resolve_target_entity**

Replace `resolve_target_entity` and add `fetch_remote_object` in `lib/fediverse/inbox/announce_handler.rb`:

```ruby
private

def dispatch_callback(entity, callback_name, actor)
  previous_actor = entity.current_federails_activity_actor
  entity.current_federails_activity_actor = actor
  entity.run_callbacks(callback_name) { true }
ensure
  entity.current_federails_activity_actor = previous_actor
end

def resolve_target_entity(object)
  entity = Federails::Utils::Object.find_or_initialize(object)
  return entity if entity.is_a?(Federails::DataEntity) && entity.persisted?

  fetch_remote_object(object)
rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
  fetch_remote_object(object)
end

def fetch_remote_object(object)
  url = object.is_a?(Hash) ? object['id'] : object
  return nil unless url.is_a?(String)

  fetched = Fediverse::Request.dereference(url)
  return nil unless fetched.is_a?(Hash)

  entity = Federails::Utils::Object.find_or_initialize(fetched)
  return entity if entity.is_a?(Federails::DataEntity) && entity.persisted?

  nil
rescue StandardError => e
  Federails.logger.warn { "[AnnounceHandler] Remote fetch failed for #{url}: #{e.message}" }
  nil
end
```

- [ ] **Step 4: Run all announce handler tests**

Run: `bundle exec rspec spec/lib/fediverse/inbox/announce_handler_spec.rb`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/fediverse/inbox/announce_handler.rb spec/lib/fediverse/inbox/announce_handler_spec.rb
git commit -m "feat: AnnounceHandler에서 로컬에 없는 object를 리모트 fetch

로컬 entity가 없으면 Fediverse::Request.dereference로 fetch 시도.
실패시 Announce 자체는 정상 처리.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 4: G4 — LD Signatures → Announce 연동

**Files:**
- Modify: `lib/fediverse/inbox/announce_handler.rb`
- Modify: `spec/lib/fediverse/inbox/announce_handler_spec.rb`

- [ ] **Step 1: Write failing test — LD Signature verification is called for signed objects**

In `spec/lib/fediverse/inbox/announce_handler_spec.rb`, add inside the `describe '.handle_announce'` block:

```ruby
context 'when object has an LD signature' do
  let(:signed_object) do
    {
      'type'      => 'Note',
      'id'        => entity.federated_url,
      'content'   => 'signed content',
      'signature' => {
        'type'           => 'RsaSignature2017',
        'creator'        => 'https://remote.example/actor#main-key',
        'created'        => '2026-04-01T00:00:00Z',
        'signatureValue' => 'abc123',
      },
    }
  end
  let(:activity) { { 'type' => 'Announce', 'actor' => 'https://remote.example/actor', 'object' => signed_object } }

  it 'calls LinkedDataSignature.verify and passes result to callback' do
    allow(Federails::Utils::Object).to receive(:find_or_initialize).with(signed_object).and_return(entity)
    allow(Fediverse::LinkedDataSignature).to receive(:verify).with(signed_object).and_return({ verified: true, actor: nil })
    allow(entity).to receive(:run_callbacks).with(:on_federails_announce_received).and_yield

    described_class.handle_announce(activity)

    expect(Fediverse::LinkedDataSignature).to have_received(:verify).with(signed_object)
  end
end

context 'when object has a failed LD signature' do
  let(:signed_object) do
    {
      'type'      => 'Note',
      'id'        => entity.federated_url,
      'content'   => 'tampered content',
      'signature' => {
        'type'           => 'RsaSignature2017',
        'creator'        => 'https://remote.example/actor#main-key',
        'created'        => '2026-04-01T00:00:00Z',
        'signatureValue' => 'bad',
      },
    }
  end
  let(:activity) { { 'type' => 'Announce', 'actor' => 'https://remote.example/actor', 'object' => signed_object } }

  it 'still processes the activity (does not reject)' do
    allow(Federails::Utils::Object).to receive(:find_or_initialize).with(signed_object).and_return(entity)
    allow(Fediverse::LinkedDataSignature).to receive(:verify).with(signed_object).and_return({ verified: false, error: 'bad sig' })
    allow(entity).to receive(:run_callbacks).with(:on_federails_announce_received).and_yield

    expect(described_class.handle_announce(activity)).to be true
  end
end

context 'when object has no LD signature' do
  let(:activity) { { 'type' => 'Announce', 'object' => entity.federated_url } }

  it 'does not call LinkedDataSignature.verify' do
    allow(Federails::Utils::Object).to receive(:find_or_initialize).with(entity.federated_url).and_return(entity)
    allow(entity).to receive(:run_callbacks).with(:on_federails_announce_received).and_yield

    described_class.handle_announce(activity)

    expect(Fediverse::LinkedDataSignature).not_to have_received(:verify) if Fediverse::LinkedDataSignature.respond_to?(:verify)
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/lib/fediverse/inbox/announce_handler_spec.rb -e 'LD signature'`
Expected: FAIL — current code does not call `LinkedDataSignature.verify`

- [ ] **Step 3: Implement LD Signature verification in handle_announce**

In `lib/fediverse/inbox/announce_handler.rb`, add `require 'fediverse/linked_data_signature'` at the top, and modify `handle_announce`:

```ruby
require 'fediverse/request'
require 'fediverse/linked_data_signature'

module Fediverse
  class Inbox
    module AnnounceHandler
      class << self
        def handle_announce(activity)
          object = activity['object']
          entity = resolve_target_entity(object)

          verify_ld_signature(object) if object.is_a?(Hash) && object['signature'].present?

          return true unless entity

          dispatch_callback(entity, :on_federails_announce_received, activity['actor'])
        end

        def handle_undo_announce(activity)
          original_activity = Fediverse::Request.dereference(activity['object'])
          return false unless original_activity && activity['actor'] == original_activity['actor']

          entity = resolve_target_entity(original_activity&.dig('object'))
          return true unless entity

          dispatch_callback(entity, :on_federails_undo_announce_received, activity['actor'])
        end

        private

        def verify_ld_signature(object)
          result = Fediverse::LinkedDataSignature.verify(object)
          if result[:verified]
            Federails.logger.info { "[AnnounceHandler] LD Signature verified for #{object['id']}" }
          else
            Federails.logger.warn { "[AnnounceHandler] LD Signature verification failed for #{object['id']}: #{result[:error]}" }
          end
          result
        end

        def dispatch_callback(entity, callback_name, actor)
          previous_actor = entity.current_federails_activity_actor
          entity.current_federails_activity_actor = actor
          entity.run_callbacks(callback_name) { true }
        ensure
          entity.current_federails_activity_actor = previous_actor
        end

        def resolve_target_entity(object)
          entity = Federails::Utils::Object.find_or_initialize(object)
          return entity if entity.is_a?(Federails::DataEntity) && entity.persisted?

          fetch_remote_object(object)
        rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
          fetch_remote_object(object)
        end

        def fetch_remote_object(object)
          url = object.is_a?(Hash) ? object['id'] : object
          return nil unless url.is_a?(String)

          fetched = Fediverse::Request.dereference(url)
          return nil unless fetched.is_a?(Hash)

          entity = Federails::Utils::Object.find_or_initialize(fetched)
          return entity if entity.is_a?(Federails::DataEntity) && entity.persisted?

          nil
        rescue StandardError => e
          Federails.logger.warn { "[AnnounceHandler] Remote fetch failed for #{url}: #{e.message}" }
          nil
        end
      end
    end
  end
end
```

- [ ] **Step 4: Run all announce handler tests**

Run: `bundle exec rspec spec/lib/fediverse/inbox/announce_handler_spec.rb`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/fediverse/inbox/announce_handler.rb spec/lib/fediverse/inbox/announce_handler_spec.rb
git commit -m "feat: AnnounceHandler에서 LD Signature 검증 연동

object에 signature 블록이 있으면 LinkedDataSignature.verify 호출.
검증 실패해도 activity는 거부하지 않고 경고 로그만 기록.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 5: G5 — Inbound bto/bcc 방어적 무시

**Files:**
- Modify: `lib/fediverse/inbox.rb`
- Modify: `spec/lib/fediverse/inbox_spec.rb`

- [ ] **Step 1: Write failing test — inbound bto/bcc are not persisted**

First check existing inbox_spec structure:

In `spec/lib/fediverse/inbox_spec.rb`, add a new describe block (or add to existing `record_processed_activity` tests if they exist):

```ruby
describe '.dispatch_request bto/bcc stripping' do
  let(:local_actor) { FactoryBot.create(:local_actor) }
  let(:remote_actor_url) { 'https://remote.example/users/alice' }

  let(:payload) do
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id'       => "https://remote.example/activity/#{SecureRandom.uuid}",
      'type'     => 'Follow',
      'actor'    => remote_actor_url,
      'object'   => local_actor.federated_url,
      'to'       => [local_actor.federated_url],
      'cc'       => [],
      'bto'      => ['https://remote.example/users/secret'],
      'bcc'      => ['https://remote.example/users/hidden'],
    }
  end

  it 'does not persist bto/bcc from inbound activity' do
    result = described_class.dispatch_request(payload)
    expect(result).to be true

    recorded = Federails::Activity.find_by(federated_url: payload['id'])
    next unless recorded

    expect(recorded.bto).to be_blank
    expect(recorded.bcc).to be_blank
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/lib/fediverse/inbox_spec.rb -e 'bto/bcc stripping'`
Expected: FAIL — current code persists bto/bcc as-is

- [ ] **Step 3: Implement bto/bcc stripping in record_processed_activity**

In `lib/fediverse/inbox.rb`, modify the `Federails::Activity.create!` call inside `record_processed_activity` (around line 116-126):

Replace:
```ruby
        Federails::Activity.create!(
          actor:         actor,
          action:        payload['type'],
          entity:        entity,
          federated_url: federated_url,
          to:            payload['to'],
          cc:            payload['cc'],
          bto:           payload['bto'],
          bcc:           payload['bcc'],
          audience:      payload['audience']
        )
```

With:
```ruby
        Federails::Activity.create!(
          actor:         actor,
          action:        payload['type'],
          entity:        entity,
          federated_url: federated_url,
          to:            payload['to'],
          cc:            payload['cc'],
          bto:           nil,
          bcc:           nil,
          audience:      payload['audience']
        )
```

- [ ] **Step 4: Run tests**

Run: `bundle exec rspec spec/lib/fediverse/inbox_spec.rb -e 'bto/bcc stripping'`
Expected: PASS

- [ ] **Step 5: Run full inbox spec to check for regressions**

Run: `bundle exec rspec spec/lib/fediverse/inbox_spec.rb`
Expected: ALL PASS

- [ ] **Step 6: Commit**

```bash
git add lib/fediverse/inbox.rb spec/lib/fediverse/inbox_spec.rb
git commit -m "fix: 수신 activity의 bto/bcc를 저장하지 않도록 수정

RFC 6.1에 따라 인바운드 activity의 bto/bcc는 방어적으로 무시.
핸들러에 전달되는 payload 원본은 유지.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```
