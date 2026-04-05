# P0/P1 갭 수정 스펙

> 2026-03-28 P0/P1 로드맵 평가 후 발견된 미충족 요구사항 5건에 대한 보정 스펙.
> 기존 `2026-03-28-activitypub-p0-p1-roadmap-design.md`는 원래 계획으로 보존하고, 이 문서는 평가 후 보정 사항을 기술한다.

---

## 1. 배경

P0/P1 로드맵의 10개 항목 모두에 대해 구현 시도가 들어가 있으나, 스펙 기준 완전 충족은 5건에 그침. 나머지 5건은 코드 골격은 있으나 핵심 수용 조건이 비어 있다.

### 미충족 갭 목록

| # | 항목 | 갭 요약 |
|---|---|---|
| G1 | P0-2 Shared Inbox | 로컬 수신자 resolve/검증 없이 단일 `dispatch_request` 호출 |
| G2 | P1-1 Delivery Reliability | 백오프 스케줄이 스펙과 다름 (`(n³)+5` vs 고정 스케줄), 순서 보장 미구현 |
| G3 | P1-3 Announce Activity | 리모트 object fetch/캐시 없음 |
| G4 | P1-5 LD Signatures → Announce 연동 | `LinkedDataSignature.verify`가 Announce 흐름에 연결되지 않음 |
| G5 | P1-6 Inbound bto/bcc | 수신 activity의 bto/bcc를 그대로 저장 |

---

## 2. G1: Shared Inbox 로컬 수신자 검증

**현재 상태:** `SharedInboxController#create`가 `Fediverse::Inbox.dispatch_request(payload)`를 한 번 호출. 개인 inbox 컨트롤러와 동일한 동작.

**변경:**
- `dispatch_request` 호출 전에 `to`/`cc`에서 로컬 actor를 resolve
- 로컬 수신자가 0명이면 activity를 거부(422) — 우리 서버에 해당하지 않는 activity를 처리할 이유 없음
- resolve된 로컬 수신자 목록을 로깅
- 핸들러 실행은 activity 단위 1회 유지 (수신자별 핸들러 실행은 불필요한 복잡도)

**수용 조건:**
- shared inbox로 수신한 activity의 `to`/`cc`에 로컬 actor가 있으면 정상 처리
- 로컬 actor가 없으면 422
- 로그에 resolve된 로컬 수신자 목록 출력

**수정 대상:**
- `app/controllers/federails/server/shared_inbox_controller.rb`

---

## 3. G2: Delivery Reliability 백오프 스케줄 보정

**현재 상태:** `NotifyInboxJob`이 `(executions**3)+5` 기반 재시도. 순서 보장 없음.

**변경:**
- 백오프 스케줄을 고정 값으로 교체: `[30, 60, 300, 1800, 7200, 43200]` (30s, 1m, 5m, 30m, 2h, 12h)
- 429 응답의 `Retry-After`가 있으면 고정 스케줄 대신 그 값 사용 (현재 로직 유지)
- 6회 초과 실패시 기존대로 예외 발생

**순서 보장에 대한 결정:**
- 원래 스펙의 "동일 inbox URL에 대한 직렬 실행(활동 순서 보장)" 요구사항은 **제거**한다
- 근거: ActivityPub 생태계에서 strict ordering은 사실상 기대되지 않음. Mastodon/Misskey 모두 수신측에서 순서가 뒤바뀐 activity를 처리할 수 있어야 함. concurrency key나 advisory lock의 복잡도 대비 실질적 이점이 없음

**수용 조건:**
- 1차 재시도 30초, 2차 60초, ... 6차 43200초 (12시간) 대기
- 429 + Retry-After시 해당 값 사용
- 6회 초과시 예외 raise

**수정 대상:**
- `app/jobs/federails/notify_inbox_job.rb`

---

## 4. G3: Announce Object 조건부 Fetch/캐시

**현재 상태:** `AnnounceHandler#handle_announce`가 `resolve_target_entity`로 로컬에 이미 있는 객체만 찾음. 없으면 `nil` 반환하고 `true`로 넘어감.

**변경:**
- `resolve_target_entity`에서 로컬 객체를 찾지 못하면 `Fediverse::Request.dereference(object)`로 리모트 fetch 시도
- fetch 타임아웃 5초 (Faraday 연결/읽기 타임아웃)
- fetch 성공시 결과를 `Federails::Utils::Object.find_or_initialize`로 로컬 DataEntity에 저장
- fetch 실패(타임아웃, 4xx, 5xx)시 object URI만 기록하고 핸들러는 정상 완료 — Announce 자체는 유효하므로 거부하지 않음
- `handle_undo_announce`에서도 동일한 로직 적용

**수용 조건:**
- 로컬에 없는 object를 가리키는 Announce 수신 → 리모트에서 fetch하여 저장
- 리모트 fetch 실패 → Announce는 정상 처리, object는 URI만 기록
- fetch 타임아웃이 5초를 넘지 않음

**수정 대상:**
- `lib/fediverse/inbox/announce_handler.rb`

---

## 5. G4: LD Signatures 검증을 Announce 수신 흐름에 연동

**현재 상태:** `Fediverse::LinkedDataSignature.verify`는 완전 구현되어 있지만, `AnnounceHandler`에서 호출하지 않음.

**변경:**
- `AnnounceHandler#handle_announce`에서 Announce의 `object`가 Hash이고 `signature` 블록을 포함하면 `Fediverse::LinkedDataSignature.verify(object)` 호출
- 검증 결과 처리:
  - `verified: true` → 정상 처리
  - `verified: false` → activity는 거부하지 않고 처리하되, 로그에 경고 기록. 호스트앱이 콜백에서 `verified` 상태를 확인할 수 있도록 activity metadata에 포함
- `object`에 `signature` 블록이 없으면 검증을 건너뜀 (LD Signatures는 optional)
- 이 연동은 G3의 리모트 fetch 이후에 실행 — fetch된 object에 signature가 있을 수 있으므로

**수용 조건:**
- signature가 있는 Announce object → `LinkedDataSignature.verify` 호출됨
- 검증 성공 → 정상 처리
- 검증 실패 → 정상 처리 + 경고 로그 + 호스트앱이 verified 상태 확인 가능
- signature 없음 → 검증 스킵

**수정 대상:**
- `lib/fediverse/inbox/announce_handler.rb`

---

## 6. G5: Inbound bto/bcc 방어적 무시

**현재 상태:** `Fediverse::Inbox#record_processed_activity`에서 수신한 activity의 `bto`/`bcc`를 그대로 `Federails::Activity`에 저장.

**변경:**
- `record_processed_activity`에서 `bto`/`bcc` 필드를 `nil`로 설정하여 저장하지 않음
- RFC 6.1에 따르면 수신측에서 `bto`/`bcc`가 도착하는 것 자체가 비정상 (발신측이 strip해야 함). 있더라도 무시하는 것이 방어적으로 올바름
- 핸들러에 전달되는 payload는 원본 유지 — 핸들러가 원본 payload를 볼 수 있어야 디버깅에 유리. 저장 단계에서만 제거

**수용 조건:**
- 수신 activity에 `bto`/`bcc`가 있어도 `Federails::Activity` 레코드에는 저장되지 않음
- 핸들러에 전달되는 payload는 원본 유지

**수정 대상:**
- `lib/fediverse/inbox.rb` (`record_processed_activity` 메서드)
