# Federails ActivityPub P0/P1 통합 로드맵 스펙

> Federails v0.8.0 기준. 기존 docs/plans/ 문서 6건을 통합 재정리한 단일 스펙.
> 연합 대상: Mastodon + Misskey/Calckey 계열 우선.

---

## 1. 현황 베이스라인 (v0.8.0)

### Discovery & Metadata
- WebFinger (`/.well-known/webfinger`) — 완전 구현
- Host-meta (`/.well-known/host-meta`) — 완전 구현
- NodeInfo 2.0 — 완전 구현, 커스텀 메타데이터 지원

### Actor System
- 다형성 Actor (로컬/리모트), RSA 키쌍 생성, Tombstone 상태
- `acts_as_federails_actor` concern, 리모트 actor 동기화
- Host 모델 (리모트 서버 정보 + NodeInfo sync)

### Inbox/Outbox (S2S)
- Inbox POST, Outbox GET (OrderedCollectionPage via Pagy)
- Activity handler 등록 시스템 (와일드카드 지원)
- 기본 핸들러: Follow, Accept(Follow), Reject(Follow), Undo(Follow), Delete, Undo(Delete)
- 수신 activity 중복 제거 (federated_url 기준)
- Update same-origin 검증, 포워딩 지원

### Following
- Following 모델 (pending/accepted), followers/following 컬렉션 엔드포인트
- 리모트 following 지원 (WebFinger 경유)

### HTTP Signatures
- Outbound 서명: draft-cavage-12 (GET/POST), SHA-256 Digest 헤더
- **Inbound 검증: 미구현** (가장 큰 보안 갭)

### Activities & Delivery
- Activity 모델: to/cc/bto/bcc/audience (YAML 직렬화)
- 기본 주소 지정: `to: [PUBLIC]`, `cc: [actor.followers_url]`
- `NotifyInboxJob` — 비동기 배달, 설정 가능한 큐
- self-exclusion, Public 컬렉션 제외

### Federated Data
- DataEntity concern, DataTransformer::Note
- PublishedController, Utils::Object

---

## 2. RFC 준수 매트릭스 (갭 분석)

### ActivityPub MUST 요구사항

| # | RFC 요구사항 | 상태 | 갭 설명 |
|---|---|---|---|
| 3.1 | 객체에 고유 `id` (HTTPS URI) | ✅ 구현 | federated_url 사용 |
| 3.2 | 객체 `id`로 GET 요청시 반환 | ⚠️ 부분 | Actor/Activity는 가능, 임의 Object는 PublishedController 의존 |
| 4.1 | Actor에 inbox/outbox 필수 | ✅ 구현 | |
| 4.1 | Actor에 followers/following 컬렉션 | ✅ 구현 | |
| 5.1 | Outbox는 OrderedCollection | ⚠️ 부분 | Page만 반환, 컨테이너(totalItems + first/last) 미제공 |
| 5.2 | Inbox POST 수신 처리 | ✅ 구현 | |
| 5.2 | Inbox 수신시 중복 제거 | ✅ 구현 | federated_url 기준 |
| 5.3 | followers 컬렉션 | ✅ 구현 | Page만 반환, 컨테이너 미제공 |
| 5.5 | liked 컬렉션 | ❌ 미구현 | Like activity 자체가 없음 |
| 6.1 | delivery시 object 속성 포함 | ⚠️ 부분 | bto/bcc 수신자 제거(strip) 미확인 |
| 6.2 | 수신자 중복 제거 + self 제외 | ✅ 구현 | |
| 6.4 | Public 주소로 배달 금지 | ✅ 구현 | |
| 6.10 | shared inbox 지원 | ❌ 미구현 | 개인 inbox만 존재 |
| 7.1 | inbox POST 인증 | ❌ 미구현 | 서명 검증 없이 수락 |
| 7.1.2 | inbox 포워딩 | ✅ 구현 | maybe_forward 구현 |
| 7.3 | Update same-origin 검증 | ✅ 구현 | |
| 7.5 | Follow → 자동 Accept/Reject 또는 pending | ✅ 구현 | |
| 7.7 | Undo 처리 | ⚠️ 부분 | Undo(Follow)만, Undo(Like/Announce) 없음 |

### Mastodon/Misskey 호환 추가 요구사항

| 항목 | 상태 | 설명 |
|---|---|---|
| Inbound HTTP Signature 검증 | ❌ | Mastodon은 서명 없는 요청 거부 |
| Shared inbox | ❌ | Mastodon은 sharedInbox 우선 사용 |
| OrderedCollection 컨테이너 | ❌ | Mastodon/Misskey가 totalItems + first 기대 |
| Like activity | ❌ | Mastodon 즐겨찾기, Misskey 리액션 |
| Announce activity | ❌ | Mastodon 부스트, Misskey 리노트 |
| LD Signatures 검증 | ❌ | Misskey 계열 relay/Announce 전달시 필수 |
| Content-Type 협상 | ⚠️ | `application/activity+json` 응답은 하지만 Accept 헤더 기반 협상 미확인 |

---

## 3. 우선순위별 갭 목록

### P0 — 보안 및 기본 연합 (즉시 필요)

| # | 피처 | 근거 |
|---|---|---|
| P0-1 | Inbound HTTP Signature 검증 | 서명 없이 inbox를 수락하는 것은 보안 결함. Mastodon/Misskey 모두 상대방의 서명 검증을 전제로 동작 |
| P0-2 | Shared inbox | Actor JSON에 `endpoints.sharedInbox` 노출, shared inbox 라우트 추가, 아웃바운드 배달시 shared inbox 우선 사용. 대규모 서버와의 연합에 필수 |
| P0-3 | OrderedCollection 컨테이너 | outbox/followers/following에서 Page만 반환하는 현재 방식은 RFC 위반. `totalItems` + `first`/`last` 링크가 있는 컨테이너 응답 추가 |

### P1 — 중기 기능 확장

| # | 피처 | 근거 |
|---|---|---|
| P1-1 | Delivery reliability | ActiveJob retry + 활동 순서 보장 |
| P1-2 | Like activity | Mastodon 즐겨찾기, Misskey 리액션의 기반 |
| P1-3 | Announce activity | Mastodon 부스트, Misskey 리노트 |
| P1-4 | Block activity | 수신 차단 + 배달 목록에서 제외 |
| P1-5 | LD Signatures 검증 (verify-only) | Misskey 계열 relay/Announce 전달시 원본 서명 검증 필요 |
| P1-6 | bto/bcc strip + audience 처리 | RFC 6.1 준수 |
| P1-7 | 누락 컬렉션 구현 | liked, featured, featured_tags 컬렉션 추가 |

### P2 — 장기 (이번 구현 범위 밖)

- RFC 9421 HTTP Message Signatures
- Object Integrity Proofs
- LD Signatures 생성
- Move activity (계정 이전)
- Followers synchronization (FEP-8fcf)
- Add/Remove activity
- Flag activity
- 개발자 도구 (커버리지 매트릭스, 디버깅 rake tasks, 테스트 헬퍼)

### 명시적 비목표

- Client-to-Server ActivityPub (C2S)
- Relay 서버 지원
- Fedify 기능 전수 매칭
- 암호화 스택 전면 교체 (RSA → ed25519 전환은 P2 이후)

---

## 4. P0 상세 스펙

### P0-1: Inbound HTTP Signature 검증

**현재 상태:** `Fediverse::Signature.sign`으로 아웃바운드 서명만 존재. 인바운드 검증 로직 없음.

**구현 범위:**
- `Fediverse::Signature.verify(request:)` 메서드 추가
  - `Signature` 헤더 파싱 → `keyId`에서 actor URI 추출 → 리모트 actor의 publicKey fetch (캐시 활용)
  - signed string 재구성 후 RSA-SHA256 검증
  - Digest 헤더 검증 (POST 요청시 body의 SHA-256 매칭)
- `Server::ActivitiesController#create` (inbox POST)에 before_action으로 검증 적용
  - 실패시 401 Unauthorized 반환
  - 키 갱신 대응: 검증 실패시 actor를 re-fetch하여 1회 재시도 (키 로테이션 대응)
- 설정 옵션: `Federails.configuration.verify_signatures` (기본 `true`, 개발/테스트 환경에서 끌 수 있도록)

**테스트 기준:**
- 유효한 서명 → 정상 처리
- 서명 없음 → 401
- 잘못된 서명 → 401
- 키 로테이션 후 → re-fetch로 성공
- Digest 불일치 → 401

### P0-2: Shared Inbox

**현재 상태:** 개인 inbox (`/federation/actors/:id/inbox`)만 존재.

**구현 범위:**
- **수신:** `/federation/inbox` 라우트 추가 → `Server::SharedInboxController#create`
  - 개인 inbox와 동일한 서명 검증 + activity 처리 파이프라인 공유
  - activity의 `to`/`cc`에서 로컬 수신자를 resolve하여 각각에게 dispatching
- **Actor JSON 노출:** Actor 직렬화에 `endpoints: { sharedInbox: "https://host/federation/inbox" }` 추가
- **아웃바운드 최적화:** `Fediverse::Notifier.post_to_inboxes`에서 수신자의 shared inbox가 있으면 같은 서버의 수신자를 그룹핑하여 shared inbox 1회 배달로 통합
  - 개인 inbox fallback: shared inbox가 없는 actor에게는 기존 방식 유지

**테스트 기준:**
- shared inbox로 수신한 activity가 로컬 수신자에게 정상 dispatch
- Actor JSON에 `endpoints.sharedInbox` 포함
- 같은 서버 수신자 3명 → shared inbox 1회 배달

### P0-3: OrderedCollection 컨테이너

**현재 상태:** outbox/followers/following이 OrderedCollectionPage만 반환.

**구현 범위:**
- 컬렉션 엔드포인트에 `?page=true` 파라미터 분기 추가
  - `page` 없음 → OrderedCollection 컨테이너 (`type`, `totalItems`, `first`, `last` 링크)
  - `page=true` 또는 `page=N` → 기존 OrderedCollectionPage 반환
- `Server::OrderedCollectionSerializer`에 컨테이너 모드 추가
- outbox, followers, following 3개 엔드포인트에 일괄 적용

**테스트 기준:**
- `GET /outbox` → `type: "OrderedCollection"`, `totalItems` 포함, `first` 링크 존재
- `GET /outbox?page=true` → 기존 OrderedCollectionPage

---

## 5. P1 상세 스펙

### P1-1: Delivery Reliability

**ActiveJob retry + 순서 보장**

- `NotifyInboxJob`에 `retry_on` 적용: 지수 백오프 (30s, 1m, 5m, 30m, 2h, 12h), 최대 6회
- HTTP 응답별 분류:
  - 2xx → 성공
  - 404/410 → 즉시 포기, 추가 추적 상태는 남기지 않음
  - 429 → `Retry-After` 헤더 존중
  - 5xx / 네트워크 에러 → retry 대상
- **활동 순서 보장:** 동일 target inbox에 대해 activity를 `created_at` 순으로 배달. `NotifyInboxJob`에 inbox URL 기반 concurrency key를 두어 같은 inbox에 대한 job이 직렬 실행되도록 함 (ActiveJob 백엔드가 지원하지 않으면 `federails_delivery_locks` 테이블로 advisory lock)
- **현재 범위:** 실패 배달의 별도 영속 추적이나 운영용 rake task는 포함하지 않음

### P1-2: Like Activity

- 수신 핸들러: `register_handler("Like", "*", handler, :on_like)` — 기본 핸들러는 activity 저장만 수행, 호스트앱이 오버라이드 가능
- 발신: `Federails::Activity`에 `type: "Like"` 지원, `object`에 liked 대상 URI
- `Undo(Like)` 핸들러 추가
- liked 컬렉션과 연동 (P1-7)

### P1-3: Announce Activity

- 수신 핸들러: `register_handler("Announce", "*", handler, :on_announce)`
  - Announce의 `object`를 fetch하여 로컬 캐시 (원본 콘텐츠 표시용)
  - LD Signatures가 있으면 검증 (P1-5 연동)
- 발신: `type: "Announce"`, `object`에 원본 activity/object URI
- `Undo(Announce)` 핸들러 추가

### P1-4: Block Activity

- 수신 핸들러: `register_handler("Block", "*", handler, :on_block)`
  - 기본 동작: block 관계 기록, 해당 actor의 기존 following 해제
- 발신시 배달 목록 필터링: blocked actor의 inbox 제외
- `Undo(Block)` 핸들러
- **호스트앱 위임:** 구체적 차단 정책(콘텐츠 숨김, 멘션 차단 등)은 호스트앱 책임. 엔진은 block 관계 저장과 배달 필터링만 담당

### P1-5: LD Signatures 검증 (Verify-Only)

- `Fediverse::LinkedDataSignature.verify(document:)` 메서드
  - JSON-LD 정규화 (URDNA2015), `signature` 블록 추출
  - `creator`에서 공개키 fetch → RSA-SHA256 검증
- Announce activity 수신시: 내부 activity에 LD Signature가 있으면 검증하여 원본 출처 확인
- 검증 실패시: activity를 거부하지 않고 `verified: false` 플래그 기록 (호스트앱이 정책 결정)
- 의존성: 이미 `json-ld` gem 사용 중이므로 정규화 가능

### P1-6: bto/bcc Strip + Audience 처리

- 아웃바운드 배달시:
  - `bto`/`bcc` 수신자를 배달 목록에 추가
  - 실제 전송하는 activity JSON에서 `bto`/`bcc` 필드 제거
- `audience` 필드: 배달 대상 resolve에 포함
- 인바운드: 수신한 activity의 `bto`/`bcc`가 있으면 (있을 수 없지만 방어적으로) 무시

### P1-7: 누락 컬렉션 구현

- **liked:** Actor별 `liked` 엔드포인트 (`/federation/actors/:id/liked`). Like activity 기반으로 자동 관리. OrderedCollection 컨테이너 + Page 형식 (P0-3 패턴 재사용)
- **featured:** Actor별 `featured` 엔드포인트 (`/federation/actors/:id/featured`). 호스트앱이 pinned 항목을 지정하는 인터페이스 제공 (예: `actor.feature(object)`, `actor.unfeature(object)`)
- **featured_tags:** Actor별 `featured_tags` 엔드포인트. Mastodon 호환용. 호스트앱이 해시태그를 등록하는 인터페이스
- Actor JSON 직렬화에 `liked`, `featured`, `featuredTags` URL 추가

---

## 6. 구현 참고 자료

| 자료 | 용도 |
|---|---|
| Fedify v2.1.0 소스 | 서명 검증, LD Signatures, shared inbox 구현 참조 |
| Federails 기존 소스 (`Fediverse::Signature`, `Fediverse::Inbox`, `NotifyInboxJob` 등) | 현재 구현 기반, 확장 지점 파악 |
| ActivityPub 스펙 W3C | MUST/SHOULD 준수 기준 |
| draft-cavage-http-signatures-12 | 현재 서명 방식 기준 문서 |
| `json-ld` gem 문서 | LD Signatures 정규화(URDNA2015) 구현시 참조 |
