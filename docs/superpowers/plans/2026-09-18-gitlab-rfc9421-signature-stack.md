# GitLab RFC9421 서명 스택 이식 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-ruby:subagent-driven-development (recommended) or superpowers-ruby:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `gitlab/main`(`6d4e661`)을 머지해 RFC9421/Linzer 서명 스택과 application actor FEP를 가져오고, 프로토콜 바이트는 GitLab과 같게 두며, Alba·`pagy`·배달 에러만 로컬 어댑터로 유지한다.

**Architecture:** 한 번의 `git merge gitlab/main`으로 83커밋을 조상으로 남긴다. 서명/HTTP 파일은 GitLab(`--theirs`), Jbuilder는 삭제하고 FEP 필드는 Alba로 포팅한다. `require_signature?` 기본값은 false다. unsigned는 통과, 깨진 서명만 401.

**Tech Stack:** Ruby on Rails engine, Linzer `~> 0.8`, Faraday, Alba, RSpec, VCR, Sorbet 인라인 RBS

**Spec:** `docs/superpowers/specs/2026-09-18-gitlab-rfc9421-signature-stack-design.md`

---

## File Map

- Merge: `gitlab/main` → 로컬 `main` (충돌 정책은 Task 1)
- GitLab 유지: `lib/fediverse/signature.rb`, `lib/fediverse/signature/rfc9421.rb`, `lib/fediverse/signature/draft_cavage12.rb`, `lib/fedipub/utils/json_request.rb`, `app/models/concerns/fedipub/application_actor.rb`
- 로컬 유지+보강: `app/controllers/fedipub/server_controller.rb`, `app/controllers/concerns/fedipub/server/verify_signature.rb`, `lib/fediverse/notifier.rb`, Alba 시리얼라이저, `fedipub.gemspec`
- 삭제: 머지로 되살아난 `app/views/fedipub/server/**/*.jbuilder` 3개
- 테스트: GitLab 서명/json_request/application_actor 스펙 + 로컬 `inbox_signature_spec` 수정

---

### Task 1: `gitlab/main` 머지와 충돌 정책

**Files:** 현재 `HEAD`(`8e55212` 이후 스펙 커밋 포함)와 `gitlab/main`(`6d4e661`). 충돌 예상 파일은 아래 Step 3 목록.

- [ ] **Step 1: 머지 전 상태 확인**

Run:

```bash
git status
git fetch gitlab main
git merge-base HEAD gitlab/main
git log -1 --oneline $(git merge-base HEAD gitlab/main)
```

Expected: 작업 트리 깨끗함. merge-base는 `ed51c41` (README 직전 서명 개편).

- [ ] **Step 2: 머지 시작**

Run:

```bash
git merge --no-ff gitlab/main
```

Expected: 충돌로 실패. 충돌 파일에 `CHANGELOG.md`, `fedipub.gemspec`, `lib/fediverse/signature.rb`, `lib/fedipub/utils/json_request.rb`, `lib/fediverse/notifier.rb`, `lib/fediverse/node_info.rb`, `app/controllers/fedipub/server/web_finger_controller.rb`, jbuilder 3개(modify/delete), 관련 spec이 포함된다.

- [ ] **Step 3: GitLab 쪽을 취할 파일**

프로토콜 본체는 `--theirs`(머지 중 `gitlab/main`).

```bash
git checkout --theirs -- \
  lib/fediverse/signature.rb \
  lib/fedipub/utils/json_request.rb \
  spec/lib/fediverse/signature_spec.rb \
  spec/lib/fedipub/utils/json_request_spec.rb
git add \
  lib/fediverse/signature.rb \
  lib/fedipub/utils/json_request.rb \
  spec/lib/fediverse/signature_spec.rb \
  spec/lib/fedipub/utils/json_request_spec.rb
```

`lib/fediverse/signature/rfc9421.rb`, `lib/fediverse/signature/draft_cavage12.rb`, `app/models/concerns/fedipub/application_actor.rb`와 그 스펙은 충돌 없이 untracked/added로 들어와야 한다. 없으면 `git checkout gitlab/main --` 로 가져온다.

- [ ] **Step 4: Jbuilder는 삭제**

```bash
git rm -f \
  app/views/fedipub/server/actors/_actor.activitypub.jbuilder \
  app/views/fedipub/server/nodeinfo/index.nodeinfo.jbuilder \
  app/views/fedipub/server/web_finger/find.jrd.jbuilder
```

Expected: modify/delete 충돌 해소. Alba 포팅은 Task 5.

- [ ] **Step 5: gemspec — `linzer`만 추가, `kaminari`/`jbuilder`는 넣지 않음**

`fedipub.gemspec` 의존성 블록을 아래로 맞춘다. `alba`와 `pagy`는 로컬을 유지한다.

```ruby
  spec.add_dependency 'alba', '~> 3.0'
  spec.add_dependency 'faraday'
  spec.add_dependency 'faraday-follow_redirects'
  spec.add_dependency 'json-ld', '>= 3.2.0'
  spec.add_dependency 'json-ld-preloaded', '>= 3.2.0'
  spec.add_dependency 'linzer', '~> 0.8'
  spec.add_dependency 'ostruct', '>= 0.6.3'
  spec.add_dependency 'pagy', '>= 43'
  spec.add_dependency 'pundit', '>= 2.3.0'
  spec.add_dependency 'rails', '>= 7.2.0'
```

```bash
git add fedipub.gemspec
```

- [ ] **Step 6: CHANGELOG Unreleased는 양쪽 유지**

`## [Unreleased]` 아래에 GitLab Added/Changed/Maintenance와 로컬 Fixed를 Keep a Changelog 순서로 둔다.

```markdown
## [Unreleased]

### Added

- Sign outgoing POST and GET requests with RFC9421 signatures and fall back to draft-cavage-12 sig on failure
- Verify signatures on all incoming requests, if they are signed; RFC9421 is checked first, then draft-cavage-12
- Advertise RFC9421 support via `Accept-Signature` header
- Automatically create application actor to represent the server and sign outgoing GET requests
- Dicover application actor via webfinger (FEP-d556) and nodeinfo (FEP-2677)
- Advertise capabilities via application actor (FEP-844e)
- RFC9421 uses the `rsa-v1_5-sha256` key algorithm; others will be supported in future

### Changed

- Set "Fedipub/{version}" as the default user agent
- Change default Accept header in HTTP requests to proper ActivityPub content types
- Actor following/follower URLs are now optional - application actors often don't have them

### Fixed

- `Fedipub::Actor.find_by_account` documented `@return [Fedipub::Actor, nil]` while every failure path raises
  `ActiveRecord::RecordNotFound`. Documentation now matches the RBS signature; same for `Fediverse::Webfinger.fetch_actor`
  and `.fetch_actor_url`.
- Backfill `fedipub_activities.entity_type` on upgrade. The 0.9.0 rename migration only renamed tables and indexes, so
  activities stored before the rename kept `Federails::Actor` / `Federails::Activity` and their `entity` silently
  resolved to `nil`.

### Maintenance

- CI is now interruptible on failure
- Update rubocop annotation syntax
- Refactor HTTP signature code
```

GitLab 오타 `Dicover`는 업스트림과 맞추려면 그대로 두고, 고치려면 머지 이후 커밋에서만 고친다.

```bash
git add CHANGELOG.md
```

- [ ] **Step 7: 남은 충돌 파일은 마커만 제거하고 Task 2–6에서 완성**

임시로 충돌 마커를 없애 머지를 끝낸다. 완성 코드는 이후 태스크가 책임진다.

- `app/controllers/fedipub/server/web_finger_controller.rb` — 일단 GitLab `@actor` 분기를 남기고 `render formats: [:jrd]` 대신 기존 `render_serialized`를 호출하는 형태로 맞춘다 (Task 5에서 FEP 링크 완성).
- `lib/fediverse/notifier.rb` — GitLab `JsonRequest.post` 호출을 넣되, 로컬 `enqueue_deliveries` / `DeliveryError` 메서드는 지우지 않는다 (Task 4).
- `lib/fediverse/node_info.rb` — 로컬 `NODEINFO_SCHEMA_RELS`와 typed 시그니처를 유지하고, `follow_redirects:` 키워드는 GitLab `JsonRequest`에 없으므로 제거한다 (항상 리다이렉트).
- spec 충돌(`notifier_spec`, `web_finger_spec`, `actors_controller_spec`) — 마커를 제거하고 해당 태스크에서 고친다.

- [ ] **Step 8: 머지 커밋**

충돌 마커가 없어야 한다.

```bash
rg -n '<<<<<<<|=======|>>>>>>>' --glob '!docs/**' || true
git add -u
git commit -m "$(cat <<'EOF'
chore: Merge GitLab main RFC9421 signature stack

Bring gitlab/main (6d4e661) so Linzer HTTP signatures and the
application actor stay attributable to upstream commits. Jbuilder
templates stay deleted; FEP fields land in Alba next.

EOF
)"
```

Run:

```bash
git merge-base --is-ancestor gitlab/main HEAD && echo ANCESTOR_OK
git log --oneline -- lib/fediverse/signature/rfc9421.rb | head
```

Expected: `ANCESTOR_OK`. 로그에 Floppy/James Smith 커밋이 보인다.

---

### Task 2: `linzer` 설치와 GitLab 서명 스펙

**Files:**
- Modify: `fedipub.gemspec` (Task 1에서 이미 `linzer`)
- Modify: `Gemfile.lock`
- Test: `spec/lib/fediverse/signature/rfc9421_spec.rb`, `spec/lib/fediverse/signature/draft_cavage12_spec.rb`, `spec/lib/fediverse/signature_spec.rb`

- [ ] **Step 1: bundle**

```bash
bundle install
```

Expected: `linzer (~> 0.8)` 설치. `kaminari`/`jbuilder` gem이 Gemfile.lock에 새로 추가되지 않는다.

- [ ] **Step 2: GitLab 서명 스펙을 먼저 실행 (RED/GREEN 확인)**

```bash
bundle exec rspec spec/lib/fediverse/signature/rfc9421_spec.rb spec/lib/fediverse/signature/draft_cavage12_spec.rb spec/lib/fediverse/signature_spec.rb spec/lib/fedipub/utils/json_request_spec.rb
```

Expected: PASS가 목표. `JsonRequest`가 모듈 호출(`follow_redirects:`)을 더 이상 모르면 실패한다. 실패하면 Task 3에서 호출부를 고친 뒤 다시 이 명령을 돌린다.

- [ ] **Step 3: 서명 스펙이 통과하면 커밋 (lockfile)**

```bash
git add Gemfile.lock fedipub.gemspec
git commit -m "build: Add linzer for RFC9421 HTTP message signatures"
```

스펙이 아직 실패하면 이 커밋은 lockfile만 하고, 실패 원인은 Task 3에서 고친다.

---

### Task 3: `JsonRequest` 호출부 — 모듈 API → 싱글톤 API

GitLab `JsonRequest`는 `class` + `Singleton`이다. `get_json(url, params:, headers:, expected_status:, from:)`만 있고 `follow_redirects:`는 없다(항상 follow). `get`/`post`는 클래스 위임.

**Files:**
- Modify: `lib/fediverse/node_info.rb`
- Modify: `lib/fediverse/webfinger.rb`
- Modify: `spec/lib/fediverse/node_info_spec.rb`
- Modify: `spec/lib/fediverse/webfinger_spec.rb`

- [ ] **Step 1: node_info_spec의 `follow_redirects:` stub를 실패시키기**

`spec/lib/fediverse/node_info_spec.rb`에서

```ruby
allow(Fedipub::Utils::JsonRequest).to receive(:get_json).with(wk_nodeinfo_url, follow_redirects: true)
```

를 다음으로 바꾼다.

```ruby
allow(Fedipub::Utils::JsonRequest).to receive(:get_json).with(wk_nodeinfo_url)
```

- [ ] **Step 2: 테스트 실행**

```bash
bundle exec rspec spec/lib/fediverse/node_info_spec.rb
```

Expected: FAIL — 구현이 아직 `follow_redirects: true`를 넘기면 stub가 안 맞는다. 구현을 먼저 고쳤다면 PASS여도 된다. 그 경우 Step 3만 확인하고 넘어간다.

- [ ] **Step 3: `node_info.rb`에서 키워드 제거**

```ruby
response = Fedipub::Utils::JsonRequest.get_json "#{base_url(domain)}/.well-known/nodeinfo"
```

로컬 `NODEINFO_SCHEMA_RELS`(2.1 then 2.0)는 유지한다.

- [ ] **Step 4: webfinger `get_json` / Authorized Fetch**

`lib/fediverse/webfinger.rb`의 `signed_get_json`을 GitLab 프로토콜에 맞게 `JsonRequest.get`으로 바꾼다. application actor가 GET을 기본 서명하므로 별도 로컬 액터 선택이 필요 없다.

```ruby
def signed_get_json(url)
  Fedipub.logger.debug { "Retrying with signed GET for #{url}" }
  Fedipub::Utils::JsonRequest.get_json(url)
rescue Fedipub::Utils::JsonRequest::UnhandledResponseStatus => e
  Fedipub.logger.debug { e.message }
  raise ActiveRecord::RecordNotFound
rescue Faraday::ConnectionFailed
  Fedipub.logger.debug { "Failed to reach server for signed GET #{url}" }
  raise ActiveRecord::RecordNotFound
rescue JSON::ParserError
  Fedipub.logger.debug { "Invalid JSON response for signed GET #{url}" }
  raise ActiveRecord::RecordNotFound
rescue URI::InvalidURIError
  Fedipub.logger.debug { "Invalid URI for signed GET #{url}" }
  raise ActiveRecord::RecordNotFound
end
```

일반 GET:

```ruby
Fedipub::Utils::JsonRequest.get_json(url, params: params, headers: { accept: 'application/json' })
```

`follow_redirects:` 인자를 제거한다.

`spec/lib/fediverse/webfinger_spec.rb`의 `Fediverse::Signature.signed_get` stub를 `Fedipub::Utils::JsonRequest.get_json` stub로 바꾼다.

- [ ] **Step 5: 테스트**

```bash
bundle exec rspec spec/lib/fediverse/node_info_spec.rb spec/lib/fediverse/webfinger_spec.rb spec/lib/fedipub/utils/json_request_spec.rb
```

Expected: PASS

- [ ] **Step 6: 커밋**

```bash
git add lib/fediverse/node_info.rb lib/fediverse/webfinger.rb spec/lib/fediverse/node_info_spec.rb spec/lib/fediverse/webfinger_spec.rb
git commit -m "refactor: Route JSON HTTP through GitLab JsonRequest singleton"
```

---

### Task 4: Notifier 배달 에러 어댑터

프로토콜(서명된 POST)은 `JsonRequest.post`. 잡 재시도는 로컬 `PermanentDeliveryError` / `TemporaryDeliveryError`.

**Files:**
- Modify: `lib/fediverse/notifier.rb`
- Test: `spec/lib/fediverse/notifier_spec.rb`
- Keep: `app/jobs/fedipub/notify_inbox_job.rb`, `lib/fedipub/delivery_errors.rb`

- [ ] **Step 1: 실패 테스트 — 410은 PermanentDeliveryError**

`spec/lib/fediverse/notifier_spec.rb`의 배달 에러 예제가 `JsonRequest.post`를 거치는지 확인하고, 없으면 추가한다.

```ruby
it 'raises PermanentDeliveryError on 410' do
  allow(Fedipub::Utils::JsonRequest).to receive(:post).and_return(
    instance_double(Faraday::Response, status: 410, body: 'gone', headers: {})
  )

  expect {
    described_class.deliver_to_inbox(activity, 'https://remote.example/inbox')
  }.to raise_error(Fedipub::PermanentDeliveryError)
end
```

`activity` let은 기존 notifier_spec과 같은 로컬 액터 활동으로 둔다.

- [ ] **Step 2: 실행**

```bash
bundle exec rspec spec/lib/fediverse/notifier_spec.rb -e 'PermanentDeliveryError on 410'
```

Expected: FAIL until `post_to_inbox`가 상태를 매핑한다.

- [ ] **Step 3: `post_to_inbox` 구현**

`Fediverse::Notifier`의 `post_to_inbox`를 아래로 맞춘다. `enqueue_deliveries` / `deliver_to_inbox` / `payload` / `validate_message!`는 유지한다.

```ruby
def post_to_inbox(inbox_url:, message:, from: nil)
  resp = Fedipub::Utils::JsonRequest.post(url: inbox_url, message: message, from: from)
  status = resp.status
  return resp if status.between?(200, 299)

  if permanent_delivery_status?(status)
    raise Fedipub::PermanentDeliveryError.new(
      delivery_error_message(inbox_url: inbox_url, status: status, body: resp.body, retry_after: nil, permanent: true),
      response_code: status, inbox_url: inbox_url
    )
  else
    retry_after = resp.headers['Retry-After'] if status == 429
    raise Fedipub::TemporaryDeliveryError.new(
      delivery_error_message(inbox_url: inbox_url, status: status, body: resp.body, retry_after: retry_after, permanent: false),
      response_code: status, inbox_url: inbox_url, retry_after: retry_after&.to_i
    )
  end
rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::SSLError => e
  raise Fedipub::TemporaryDeliveryError.new(
    "Delivery to #{inbox_url} failed: #{e.class} #{e.message}",
    response_code: nil, inbox_url: inbox_url
  )
end
```

직접 Faraday를 서명하던 `signed_request` / `request` / `digest`는 제거한다. 서명은 `JsonRequest`가 한다.

- [ ] **Step 4: 테스트**

```bash
bundle exec rspec spec/lib/fediverse/notifier_spec.rb spec/jobs/fedipub/notify_inbox_job_spec.rb
```

Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add lib/fediverse/notifier.rb spec/lib/fediverse/notifier_spec.rb
git commit -m "refactor: Deliver via JsonRequest and keep local delivery errors"
```

---

### Task 5: application actor FEP를 Alba로 포팅

Jbuilder 필드와 동등한 JSON. 컨트롤러는 `@actor` 기준으로 렌더한다.

**Files:**
- Modify: `app/serializers/fedipub/server/actor_resource.rb`
- Modify: `app/serializers/fedipub/server/web_finger_resource.rb`
- Modify: `app/serializers/fedipub/server/nodeinfo_index_resource.rb`
- Modify: `app/controllers/fedipub/server/web_finger_controller.rb`
- Modify: `app/controllers/fedipub/server/nodeinfo_controller.rb`
- Test: `spec/requests/web_finger_spec.rb`, `spec/requests/nodeinfo_spec.rb`, `spec/requests/federation/actors_spec.rb`, `spec/models/concerns/fedipub/application_actor_spec.rb`

- [ ] **Step 1: 실패 테스트 — nodeinfo index에 Application 링크**

`spec/requests/nodeinfo_spec.rb`에 (GitLab이 이미 넣었으면 그것을 쓴다):

```ruby
it 'includes the application actor link' do
  get '/.well-known/nodeinfo', headers: { 'Accept' => 'application/json' }

  expect(response.parsed_body['links']).to include(
    hash_including(
      'rel'  => 'https://www.w3.org/ns/activitystreams#Application',
      'href' => Fedipub::Actor.application_actor.federated_url
    )
  )
end
```

- [ ] **Step 2: 실행**

```bash
bundle exec rspec spec/requests/nodeinfo_spec.rb -e 'application actor link'
```

Expected: FAIL — `NodeinfoIndexResource`가 schema 2.0 링크만 낸다.

- [ ] **Step 3: `NodeinfoIndexPayload` / Resource**

```ruby
NodeinfoIndexPayload = Struct.new(
  :href,                 #: untyped
  :application_actor_href #: untyped
)

class NodeinfoIndexResource < BaseResource
  attribute :links do |payload|
    [
      {
        rel:  'http://nodeinfo.diaspora.software/ns/schema/2.0',
        href: payload.href,
      },
      {
        rel:  'https://www.w3.org/ns/activitystreams#Application',
        href: payload.application_actor_href,
      },
    ]
  end
end
```

`NodeinfoController#index`:

```ruby
render_serialized(
  Fedipub::Server::NodeinfoIndexResource,
  Fedipub::Server::NodeinfoIndexPayload.new(
    href:                    show_node_info_url,
    application_actor_href:  Fedipub::Actor.application_actor.federated_url
  ),
  content_type: Mime[:nodeinfo]
)
```

- [ ] **Step 4: ActorResource `implements` / `generator`**

`app/serializers/fedipub/server/actor_resource.rb`에 GitLab Jbuilder와 같은 필드를 추가한다.

```ruby
attribute :implements do |actor|
  next unless actor.application_actor?

  [
    'https://www.w3.org/TR/activitypub/',
    'https://datatracker.ietf.org/doc/html/rfc9421',
    'https://datatracker.ietf.org/doc/html/draft-cavage-http-signatures-12',
    'https://w3id.org/fep/844e',
    'https://w3id.org/fep/2677',
    'https://w3id.org/fep/d556',
  ].map { |url| { 'href' => url } }
end

attribute :generator do |actor|
  next if actor.application_actor?

  Fedipub::Actor.application_actor.federated_url
end
```

Alba가 nil attribute를 omit하지 않으면 `if:` / `nil` 정책을 기존 `BaseResource` 패턴에 맞춘다.

- [ ] **Step 5: WebFinger — application actor와 Service rel**

`WebFingerPayload`에 `service_href`(optional)를 추가하거나, `self_href` + `application_actor` 플래그를 둔다.

`WebFingerController#find`는 GitLab 분기를 쓰고 Alba로 렌더한다.

```ruby
def find
  skip_authorization

  case resource = params.require(:resource)
  when %r{^https?://#{Regexp.escape(Fedipub::Utils::Host.localhost)}/?$}
    @actor = Fedipub::Actor.application_actor
  when %r{^https?://.+}
    @actor = Fedipub::Actor.find_by_federation_url!(resource)
  when /^acct:.+/
    @actor = Fedipub::Actor.find_local_by_username(username)
    raise Fedipub::Actor::TombstonedError if @actor&.tombstoned?
  end
  raise ActiveRecord::RecordNotFound if @actor.nil?

  links_payload = Fedipub::Server::WebFingerPayload.new(
    subject:            resource,
    self_href:          @actor.federated_url,
    profile_href:       @actor.profile_url,
    remote_follow_url:  remote_follow_url,
    application_actor:  @actor.application_actor?
  )
  render_serialized(Fedipub::Server::WebFingerResource, links_payload, content_type: Mime[:jrd])
end
```

`WebFingerResource#links`에 application actor이면 GitLab과 같은 Service rel을 추가한다.

```ruby
if payload.application_actor
  links << {
    rel:  'https://www.w3.org/ns/activitystreams#Service',
    type: Mime[:activitypub].to_s,
    href: payload.self_href,
  }
end
```

`acct:` / URL 조회는 `@user.entity`가 아니라 `@actor`다. application actor는 `entity`가 nil이다.

- [ ] **Step 6: 테스트**

```bash
bundle exec rspec spec/requests/nodeinfo_spec.rb spec/requests/web_finger_spec.rb spec/requests/federation/actors_spec.rb spec/models/concerns/fedipub/application_actor_spec.rb
```

Expected: PASS. `require_signature?`를 true로 스텁하는 GitLab request 스펙이 있으면 그대로 둔다(기본 false 프로토콜을 바꾸지 않음).

- [ ] **Step 7: 커밋**

```bash
git add app/serializers/fedipub/server/actor_resource.rb \
  app/serializers/fedipub/server/web_finger_resource.rb \
  app/serializers/fedipub/server/nodeinfo_index_resource.rb \
  app/controllers/fedipub/server/web_finger_controller.rb \
  app/controllers/fedipub/server/nodeinfo_controller.rb \
  spec/requests/nodeinfo_spec.rb spec/requests/web_finger_spec.rb
git commit -m "feat: Port application actor FEP fields to Alba serializers"
```

---

### Task 6: 수신 검증 — GitLab `ServerController` + 로컬 `@signed_actor`

**Files:**
- Modify: `app/controllers/fedipub/server_controller.rb`
- Modify: `app/controllers/concerns/fedipub/server/verify_signature.rb`
- Modify: `app/controllers/fedipub/server/activities_controller.rb`
- Modify: `app/controllers/fedipub/server/shared_inbox_controller.rb`
- Test: `spec/requests/federation/inbox_signature_spec.rb`

- [ ] **Step 1: inbox_signature_spec — unsigned는 통과, 깨진 서명은 401**

`spec/requests/federation/inbox_signature_spec.rb`에서 unsigned 401 예제를 삭제하거나 아래처럼 바꾼다.

```ruby
it 'accepts unsigned POST when require_signature? is false' do
  post fedipub.server_actor_inbox_path(actor), params: payload, headers: { 'Content-Type' => 'application/activity+json' }

  expect(response).not_to have_http_status(:unauthorized)
end
```

깨진 서명:

```ruby
it 'rejects a malformed Signature header with 401' do
  post fedipub.server_actor_inbox_path(actor),
       params:  payload,
       headers: {
         'Content-Type' => 'application/activity+json',
         'Signature'    => 'not-a-valid-signature',
       }

  expect(response).to have_http_status(:unauthorized)
end
```

유효 서명은 GitLab `Signature.sign`(요청 객체 반환)으로 헤더를 복사한다.

```ruby
def signature_headers_for(signing_actor, body)
  request = build_signature_request(body)
  signed = Fediverse::Signature.sign(sender: signing_actor, request: request)
  signed.headers.slice('Host', 'Date', 'Digest', 'Content-Digest', 'Signature', 'Signature-Input', 'Content-Type')
end
```

`Fediverse::Signature.sign`이 String을 반환하면 이 헬퍼는 실패한다. GitLab 모듈이면 요청 객체다.

- [ ] **Step 2: 실행**

```bash
bundle exec rspec spec/requests/federation/inbox_signature_spec.rb
```

Expected: unsigned 예제는 ServerController에 `verify_request_signature!`가 없으면 이미 통과할 수 있다. malformed는 아직 통과해서 FAIL이어야 한다.

- [ ] **Step 3: ServerController에 GitLab 훅을 넣되 Pagy/`render_serialized`는 유지**

```ruby
module Fedipub
  class ServerController < ::ActionController::Base # rubocop:disable Rails/ApplicationController
    include Pagy::Method
    include Pundit::Authorization
    include Fedipub::ServerHelper

    before_action :verify_request_signature!
    after_action :verify_authorized

    protect_from_forgery with: :null_session
    helper Fedipub::ServerHelper

    rescue_from ActiveRecord::RecordNotFound, with: :error_not_found
    rescue_from Fedipub::Actor::TombstonedError,
                Fedipub::DataEntity::TombstonedError,
                with: :error_gone

    def self.require_signature?
      false
    end

    private

    def verify_request_signature!
      return if defined?(Fedipub::Configuration) && Fedipub::Configuration.respond_to?(:verify_signatures) &&
                Fedipub::Configuration.verify_signatures == false

      Fediverse::Signature.verify!(request: request, require_signature: self.class.require_signature?)
    rescue Fediverse::Signature::BadSignature => e
      Fedipub.logger.warn do
        {
          message:         "Signature verification failed: #{e.message}",
          remote_ip:       request.remote_ip,
          signature_input: request.headers['Signature-Input'],
        }
      end
      head :unauthorized
    end
    # error_fallback / render_serialized 기존 유지
  end
end
```

`require_signature?` 기본 false를 바꾸지 않는다.

- [ ] **Step 4: `verify_http_signature!`가 unsigned를 다시 401로 만들지 않게**

inbox `before_action :verify_http_signature!`는 `@signed_actor`만 채운다. 서명 없으면 return. 서명이 있으면 keyId로 Actor를 찾고, `BadSignature`는 이미 ServerController가 처리한다.

```ruby
def verify_http_signature!
  return unless Fedipub::Configuration.verify_signatures
  return if request.headers['Signature'].blank? && request.headers['Signature-Input'].blank?

  @signed_actor = actor_from_signature_key_id(request)
rescue Fediverse::Signature::BadSignature, Fediverse::Signature::SignatureVerificationError => e
  log_signature_failure(e)
  head :unauthorized
end
```

`SignatureVerificationError`가 없으면:

```ruby
module Fediverse
  module Signature
    SignatureVerificationError = BadSignature
  end
end
```

를 `lib/fediverse/signature.rb` 모듈 안에 둔다. 업스트림 `verify!` 시그니처는 바꾸지 않는다.

`actor_match?`는 `@signed_actor`가 있을 때만 대조한다. unsigned면 true.

inbox 컨트롤러의 `before_action :verify_http_signature!`는 남겨도 되고, ServerController와 중복 401이 없도록 unsigned early return이 필수다.

- [ ] **Step 5: 테스트**

```bash
bundle exec rspec spec/requests/federation/inbox_signature_spec.rb spec/requests/federation/shared_inbox_spec.rb spec/requests/federation/activities_spec.rb
```

Expected: PASS. unsigned inbox는 401이 아니다.

- [ ] **Step 6: 커밋**

```bash
git add app/controllers/fedipub/server_controller.rb \
  app/controllers/concerns/fedipub/server/verify_signature.rb \
  lib/fediverse/signature.rb \
  spec/requests/federation/inbox_signature_spec.rb
git commit -m "feat: Verify inbound signatures like GitLab when present"
```

---

### Task 7: 인라인 RBS와 전체 검증

**Files:** GitLab에서 가져온 Ruby 파일 (`signature.rb`, `rfc9421.rb`, `draft_cavage12.rb`, `json_request.rb`, `application_actor.rb`)

- [ ] **Step 1: `bin/srb tc`**

```bash
bin/srb tc
```

Expected: GitLab 파일에 `# typed:` / `#:`가 없으면 에러가 날 수 있다.

- [ ] **Step 2: 최소 인라인 RBS**

각 파일 상단에 `# typed: true` 또는 기존 엔진 관례(`# typed: false`는 Actor 같은 모델만)를 맞춘다. 공개 메서드에 `#:` 시그니처를 붙인다. 예:

```ruby
# typed: true
# rbs_inline: enabled

module Fediverse
  module Signature
    class << self
      #: (sender: Fedipub::Actor, request: untyped, ?legacy_signature: bool) -> untyped
      def sign(sender:, request:, legacy_signature: false)
```

Faraday/Linzer 요청 타입은 `untyped`로 둬도 된다. 동작을 바꾸지 않는다.

- [ ] **Step 3: RuboCop**

```bash
bundle exec rubocop lib/fediverse/signature.rb lib/fediverse/signature lib/fedipub/utils/json_request.rb app/models/concerns/fedipub/application_actor.rb app/controllers/fedipub/server_controller.rb
```

Expected: 신규 offense 없음. `disable-next`가  redund하면 제거한다.

- [ ] **Step 4: 전체 테스트**

```bash
bundle exec rspec
bin/srb tc
```

Expected: 0 failures. VCR이 서명된 GET 때문에 깨지면 해당 카세트만 `VCR_RECORD=new_episodes` 또는 프로젝트 관례대로 재녹음한다. 카세트 외 로직 변경은 하지 않는다.

- [ ] **Step 5: 커밋**

```bash
git add -u
git commit -m "chore: Type GitLab signature stack and refresh VCR cassettes"
```

- [ ] **Step 6: 성공 조건 확인**

```bash
git merge-base --is-ancestor gitlab/main HEAD && echo ANCESTOR_OK
git log --oneline -- lib/fediverse/signature/rfc9421.rb | head
test ! -f app/views/fedipub/server/actors/_actor.activitypub.jbuilder && echo NO_JBUILDER
```

Expected: `ANCESTOR_OK`, GitLab 커밋이 로그에 있음, Jbuilder 없음.

---

## Spec coverage

| Spec 요구 | Task |
|---|---|
| `gitlab/main` 머지로 SHA 추적 | 1 |
| Linzer RFC9421 + cavage + JsonRequest | 1–3 |
| double-knock / GET 기본 application actor | 1, 3 (GitLab JsonRequest) |
| `require_signature?` false, unsigned 통과, 깨진 서명 401 | 6 |
| application actor FEP JSON via Alba | 5 |
| Jbuilder 비복구, pagy 유지, kaminari 금지 | 1 Step 4–5 |
| DeliveryError 어댑터 | 4 |
| `bin/srb tc` + 관련 spec | 7 |

## 실행 시 주의

- 머지 중 `kaminari`나 `jbuilder` gemspec 줄을 되살리지 말 것.
- `verify!(require_signature: true)`를 기본 경로에 넣지 말 것.
- `Signature.sign` 반환값은 Faraday 요청 객체다. 헤더 문자열로 취급하지 말 것.
