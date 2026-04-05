# P2 ActivityPub 장기 로드맵 스펙

> P0/P1 이후의 장기 기능 확장 8건에 대한 설계 방향 및 수용 조건.
> 각 항목은 구현 시점에 별도 구현 플랜을 작성한다. 이 문서는 방향 잡기에 집중한다.

---

## 1. 항목 개요

| # | 항목 | 성격 | 의존관계 |
|---|---|---|---|
| P2-1 | RFC 9421 HTTP Message Signatures | 프로토콜 확장 | 없음 |
| P2-2 | Object Integrity Proofs | 프로토콜 확장 | ed25519 gem |
| P2-3 | LD Signatures 생성 | 프로토콜 확장 | P1-5 LD Sig 검증 |
| P2-4 | Move activity (계정 이전) | 기능 확장 | 없음 |
| P2-5 | Followers synchronization (FEP-8fcf) | 기능 확장 | P0-1 Inbound Sig 검증 |
| P2-6 | Add/Remove activity | 기능 확장 | P1-7 featured 컬렉션 |
| P2-7 | Flag activity | 기능 확장 | 없음 |
| P2-8 | 개발자 도구 | 도구 | 모든 P0/P1 완료 후 |

### 명시적 비목표 (변경 없음)

- Client-to-Server ActivityPub (C2S)
- Relay 서버 지원
- Fedify 기능 전수 매칭
- 암호화 스택 전면 교체 (RSA → ed25519 전환은 P2 이후)

---

## 2. P2-1: RFC 9421 HTTP Message Signatures

**배경:** 현재 Federails는 draft-cavage-12 서명 방식을 사용. RFC 9421은 이를 대체하는 IETF 표준으로, Mastodon은 아직 draft-cavage를 사용하지만 점진적 전환이 예상됨.

**설계 방향:**
- `Fediverse::Signature`에 RFC 9421 서명/검증을 별도 모듈로 추가 (기존 draft-cavage와 병존)
- 인바운드: `Signature` 헤더와 `Signature-Input` 헤더 존재 여부로 RFC 9421 vs draft-cavage 자동 감지
- 아웃바운드: 설정으로 서명 방식 선택 (`Federails.configuration.signature_algorithm`). 기본값은 draft-cavage (호환성), 옵트인으로 RFC 9421
- 서명 알고리즘: `rsa-pss-sha512` (RFC 9421 권장) + `rsa-v1_5-sha256` (draft-cavage 호환)

**의존관계:** 없음 (독립 구현 가능)

**수용 조건:**
- RFC 9421 `Signature-Input` + `Signature` 헤더를 가진 요청을 검증 가능
- RFC 9421 방식으로 아웃바운드 서명 생성 가능
- draft-cavage 요청도 기존대로 처리 (하위 호환)

**비목표:** ed25519 키 지원은 별도 항목 (암호화 스택 교체는 P2 이후)

---

## 3. P2-2: Object Integrity Proofs

**배경:** FEP-8b32에서 정의. Activity JSON에 `proof` 블록을 포함하여 LD Signatures의 후속 표준 역할. Mastodon 4.3+에서 지원 시작. HTTP Signatures와 독립적으로 object 자체의 무결성을 검증할 수 있음.

**설계 방향:**
- `Fediverse::IntegrityProof` 모듈 신설
- 검증(verify-only) 우선 구현, 생성은 LD Signatures 생성과 함께 후순위
- 검증 흐름: `proof` 블록 파싱 → `verificationMethod`에서 공개키 fetch → 데이터 정규화(URDNA2015) → 서명 검증
- 지원 알고리즘: `eddsa-jcs-2022` (Mastodon 사용), `eddsa-rdfc-2022`
- 기존 `LinkedDataSignature`와 동일한 패턴: 검증 실패시 거부하지 않고 `verified: false` 기록

**의존관계:**
- ed25519 키 파싱 필요 → `ed25519` gem 추가 (서명 생성은 하지 않으므로 검증용으로만)
- JSON Canonicalization Scheme (JCS) 지원 필요 → `json-canonicalization` gem

**수용 조건:**
- `proof` 블록이 있는 activity/object의 무결성 검증 가능
- 검증 결과를 호스트앱이 확인 가능
- `proof`가 없으면 검증 스킵

**비목표:** proof 생성 (서명측), 다중 proof 체인 검증

---

## 4. P2-3: LD Signatures 생성

**배경:** 현재 `LinkedDataSignature.verify`(검증)만 있음. 생성은 Announce를 relay하거나, 다른 서버로 activity를 전달(forward)할 때 원본 출처를 증명하는 데 필요. Misskey 계열이 특히 이에 의존.

**설계 방향:**
- `Fediverse::LinkedDataSignature.sign(document:, actor:)` 메서드 추가
- 기존 `verify`의 역과정: document 정규화(URDNA2015) → options hash + document hash 생성 → actor의 private key로 RSA-SHA256 서명 → `signature` 블록 삽입
- 적용 지점:
  - `Fediverse::Inbox.maybe_forward` — forwarding시 원본 activity에 LD Signature 부착
  - 호스트앱이 명시적으로 호출할 수 있는 public API
- `signature` 블록 형식: `{ type: "RsaSignature2017", creator: actor.key_id, created: ISO8601, signatureValue: base64 }`

**의존관계:**
- 기존 `json-ld` gem, `Fediverse::LinkedDataSignature` 모듈 확장
- Actor의 private key 접근 (기존 `Fediverse::Signature.sign`과 동일 패턴)

**수용 조건:**
- `LinkedDataSignature.sign`으로 생성한 signature를 `LinkedDataSignature.verify`로 검증 가능 (round-trip)
- forwarding된 activity에 LD Signature가 포함됨
- Misskey 인스턴스가 forwarded activity의 LD Signature를 검증 가능

**비목표:** Object Integrity Proofs 방식의 서명 생성 (별도 항목)

---

## 5. P2-4: Move Activity (계정 이전)

**배경:** 사용자가 다른 서버로 계정을 이전할 때 사용. Mastodon은 Move activity를 수신하면 followers에게 새 계정을 follow하도록 안내하고, 이전 계정의 콘텐츠 표시를 전환함.

**설계 방향:**
- **수신 핸들러:** `register_handler("Move", "*", MoveHandler, :handle_move)`
  - `actor` (이전 계정)와 `target` (새 계정)을 검증
  - 검증 조건: 새 계정의 `alsoKnownAs`에 이전 계정이 포함되어 있어야 함 (Mastodon 방식의 양방향 확인)
  - 검증 통과시: 이전 계정의 로컬 followers에게 콜백 (`on_federails_move_received`) 발생. 호스트앱이 follower 이전, UI 안내 등을 결정
  - 이전 계정 Actor를 tombstone 상태로 전환하지는 않음 — 호스트앱 결정
- **발신:** `type: "Move"`, `actor: 이전 계정 URI`, `target: 새 계정 URI`
  - 발신 전 전제조건: 새 계정에서 `alsoKnownAs` 설정이 완료되어 있어야 함
- **Actor JSON:** `alsoKnownAs` 필드 추가. 호스트앱이 설정하는 인터페이스 (`actor.also_known_as = [uri]`)

**의존관계:** Actor 모델에 `also_known_as` 컬럼 추가 (JSON 배열 또는 text 배열)

**수용 조건:**
- Move 수신시 `alsoKnownAs` 양방향 검증 수행
- 검증 실패시 Move 무시 + 경고 로그
- 검증 성공시 호스트앱 콜백 발생
- Actor JSON에 `alsoKnownAs` 노출

**비목표:** followers 자동 이전 (엔진은 콜백만, 정책은 호스트앱), 콘텐츠 마이그레이션

---

## 6. P2-5: Followers Synchronization (FEP-8fcf)

**배경:** 서버 간 follower 목록이 불일치할 수 있음 (배달 실패, 서버 다운타임 등). FEP-8fcf는 `Collection-Synchronization` 헤더를 통해 followers 컬렉션의 digest를 교환하고, 불일치시 동기화하는 메커니즘. Mastodon 4.0+에서 구현.

**설계 방향:**
- **아웃바운드:** activity 배달시 `Collection-Synchronization` 헤더 추가
  - `collectionId`: 로컬 actor의 followers URL
  - `digest`: followers 목록의 SHA-256 digest (해당 서버의 follower만 필터링하여 계산)
  - `url`: 필터링된 followers 목록을 반환하는 엔드포인트
- **인바운드:** 수신한 activity에 `Collection-Synchronization` 헤더가 있으면
  - digest 비교 → 불일치시 상대 서버의 `url`을 fetch하여 로컬 follower 목록과 비교
  - 상대 서버에 없는 follower → Undo(Follow) 처리 (로컬에서 stale follow 제거)
  - 상대 서버에만 있는 follower → 무시 (상대 서버가 해결할 문제)
- **필터링된 followers 엔드포인트:** `/federation/actors/:id/followers` + `Authorization` 헤더로 요청 서버를 인증하고, 해당 서버 도메인의 follower만 반환

**의존관계:** Inbound HTTP Signature 검증 (P0-1, 구현 완료)

**수용 조건:**
- 아웃바운드 배달에 `Collection-Synchronization` 헤더 포함
- digest 불일치시 stale follow 정리
- 필터링된 followers 엔드포인트가 서명된 요청에만 응답

**비목표:** 실시간 동기화, follower 목록 전체 공개

---

## 7. P2-6: Add/Remove Activity

**배경:** `Add`와 `Remove`는 컬렉션에 객체를 추가/제거하는 activity. 대표적 용도는 pinned posts — Mastodon은 `Add(target: featured)` / `Remove(target: featured)`로 고정 게시물을 관리. P1-7에서 featured 컬렉션은 이미 구현됨.

**설계 방향:**
- **수신 핸들러:** `register_handler("Add", "*", AddRemoveHandler, :handle_add)`, `register_handler("Remove", "*", AddRemoveHandler, :handle_remove)`
  - `target`이 로컬 actor의 `featured` URL이면 → `FeaturedItem` 생성/삭제
  - `target`이 로컬 actor의 `featured_tags` URL이면 → `FeaturedTag` 생성/삭제
  - same-origin 검증: `actor`와 `target` 컬렉션의 소유자가 동일해야 함
  - 그 외 `target`은 호스트앱 콜백 (`on_federails_add_received`, `on_federails_remove_received`)으로 위임
- **발신:** 호스트앱이 `actor.feature(object)` / `actor.unfeature(object)` 호출시 자동으로 Add/Remove activity 생성 및 배달

**의존관계:** P1-7 featured/featured_tags 컬렉션 (구현 완료)

**수용 조건:**
- Add(target: featured) 수신 → FeaturedItem 생성
- Remove(target: featured) 수신 → FeaturedItem 삭제
- same-origin 검증 실패시 거부
- 알 수 없는 target → 호스트앱 콜백

**비목표:** 임의 컬렉션에 대한 범용 Add/Remove (featured/featured_tags만 엔진에서 처리)

---

## 8. P2-7: Flag Activity

**배경:** `Flag`는 신고/리포트 activity. Mastodon에서 사용자가 다른 서버의 콘텐츠를 신고하면 해당 서버로 Flag activity를 전송. `object`에 신고 대상 actor와 문제 게시물 URI 배열이 포함됨.

**설계 방향:**
- **수신 핸들러:** `register_handler("Flag", "*", FlagHandler, :handle_flag)`
  - `object` 파싱: 첫 번째 요소가 actor URI, 나머지가 콘텐츠 URI (Mastodon 관례)
  - 대상 actor가 로컬인지 검증
  - 엔진은 Flag activity를 기록만 하고, 호스트앱 콜백 (`on_federails_flag_received`)으로 위임
  - 콜백에 전달하는 정보: 신고자 actor, 대상 actor, 대상 콘텐츠 URI 목록, `content` (신고 사유)
- **발신:** 호스트앱이 신고를 생성할 때 호출할 수 있는 API (`Federails::Flag.create_and_deliver(reporter:, target_actor:, objects:, content:)`)
  - `to`는 대상 actor의 서버 inbox (Mastodon은 신고를 대상 서버에만 전송)
- **모델:** `Federails::Flag` 모델은 만들지 않음. 신고의 저장/관리는 호스트앱 책임. 엔진은 수신 콜백과 발신 헬퍼만 제공

**의존관계:** 없음

**수용 조건:**
- Flag 수신시 호스트앱 콜백에 신고자, 대상, 사유가 전달됨
- 대상 actor가 로컬이 아니면 무시
- 발신 헬퍼로 Flag activity를 대상 서버에 배달 가능

**비목표:** 신고 대시보드, 모더레이션 워크플로우 (호스트앱 영역)

---

## 9. P2-8: 개발자 도구

**배경:** ActivityPub 연합은 디버깅이 어려움 — 서명 문제, 리모트 서버 응답, activity 흐름을 추적하기 어렵고, 엔진 사용자가 현재 구현 상태를 한눈에 파악할 방법이 없음. 엔진 채택률에 직접 영향.

### Rake Tasks

- **`rake federails:status`** — 현재 구현 상태 출력. Actor 수(로컬/리모트), Following 수, 최근 배달 성공/실패 비율, 등록된 핸들러 목록
- **`rake federails:test_delivery[actor_uri]`** — 특정 actor에 테스트 activity(Note 타입) 전송. 서명, 배달, 응답 코드를 단계별 출력. 연합 연결 확인용
- **`rake federails:verify_remote[domain]`** — 리모트 서버와 핸드셰이크 검증. WebFinger → actor fetch → 서명 교환까지 단계별 성공/실패 출력
- **`rake federails:inspect_actor[uri]`** — actor JSON 출력 + 공개키 상태 + endpoints + 컬렉션 URL 접근 가능 여부

### RSpec 헬퍼

- **`Federails::TestHelper::SignedRequest`** — 서명된 inbox POST 요청을 생성하는 공유 컨텍스트. 현재 `spec/support/signature_helper.rb`에 내부용으로 있는 것을 공개 API로 정리
- **`Federails::TestHelper::ActorFactory`** — 로컬/리모트 actor를 빠르게 만드는 헬퍼. 키쌍 자동 생성 포함

### Rails Console 헬퍼

- **`Federails.debug_actor(uri)`** — actor 정보 + 키 상태 + 최근 activity 요약
- **`Federails.debug_delivery(activity)`** — 특정 activity의 배달 대상, 상태, 실패 이유 추적

**의존관계:** 모든 P0/P1 구현이 완료된 후 작업하는 것이 자연스러움

**수용 조건:**
- 4개 rake task가 동작하고 유용한 출력을 생성
- RSpec 헬퍼를 호스트앱에서 `require 'federails/test_helpers'`로 사용 가능
- console 헬퍼가 연합 디버깅에 실용적

**비목표:** 웹 기반 대시보드, Grafana/Prometheus 메트릭 연동

---

## 10. 구현 순서 권장

```
Phase 1 (독립, 병렬 가능):
  P2-1 RFC 9421
  P2-4 Move
  P2-7 Flag

Phase 2 (Phase 1 이후):
  P2-3 LD Signatures 생성
  P2-6 Add/Remove

Phase 3 (Phase 2 이후):
  P2-2 Object Integrity Proofs
  P2-5 Followers Synchronization

Phase 4 (모든 기능 안정화 후):
  P2-8 개발자 도구
```
