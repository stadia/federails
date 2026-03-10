# ActivityPub 남은 MUST 구현 계획

날짜: 2026-03-10
기준 브랜치: `main`
기준 커밋: `637d24d`
기준 문서: `report.md`

## 목적

`report.md`의 `MUST` / `MUST NOT` 항목 중 현재 `main`에서 실제 구현 TODO로 남아 있는 항목만 추려, 다음 구현 작업으로 바로 이어질 수 있는 계획으로 정리한다.

이번 계획은 다음 2개를 우선 대상으로 한다.

1. inbox POST의 ActivityPub `Content-Type` 강제
2. federation GET 엔드포인트의 `Accept` 정책 명확화 및 구현

## 배경

이미 구현된 MUST도 많다.

- inbox de-duplication
- self recipient 제외
- collection recipient dereference
- collection indirection depth 제한
- recipient list de-duplication
- forwarding
- `Update` same-origin 검증
- `Reject(Follow)` 처리
- followers/following/outbox의 `OrderedCollection` 응답

따라서 지금 남은 MUST는 “핵심 기능 부재”보다는 “엔드포인트 의미를 RFC에 더 가깝게 맞추는 작업”에 가깝다.

## 범위 제외. GET Inbox 구현

### 관련 RFC

- `5.2` Inbox는 actor profile의 `inbox`를 통해 발견되어야 함
- `5.2` Inbox는 `OrderedCollection`이어야 함

### 현재 상태

- actor object는 `inbox` URL을 노출함
- inbox는 `POST /federation/actors/:id/inbox`만 처리함
- `GET /inbox` 라우트와 collection 표현은 없음

### 현재 결론

- `GET /federation/actors/:id/inbox`는 구현하지 않는다

### 제외 이유

- 현재 Federails는 server-to-server 중심 구현 범위를 우선한다
- inbox의 실질적인 상호운용 표면은 `POST /inbox`이다
- inbox 조회를 도입하면 공개 범위, 인증, privacy 정책을 별도로 설계해야 한다
- 이 비용에 비해 현재 우선순위가 낮다

### 문서상 의미

- strict RFC 관점에서는 남는 gap이다
- 하지만 현재 구현 배치에서는 active task로 잡지 않는다
## 작업 1. Inbox POST의 ActivityPub Content-Type 강제

### 관련 RFC

- `7` server-to-server `POST` 요청은 `application/ld+json; profile="https://www.w3.org/ns/activitystreams"` 이어야 함

### 현재 상태

- outbound notifier는 올바른 `Content-Type`을 사용함
- inbound inbox는 사실상 `application/json`도 수용함
- dummy request spec도 `application/json`을 사용 중임

### 구현 목표

inbox POST가 ActivityPub media type만 허용하도록 강제한다.

### 설계 방향

- `ActivitiesController#create` 진입 시 `Content-Type` 검사
- 허용 대상:
  - `application/ld+json; profile="https://www.w3.org/ns/activitystreams"`
  - 필요 시 `application/activity+json`도 허용 여부 결정

여기서 주의할 점:

- RFC `MUST`는 `application/ld+json; profile=...`
- 같은 문서에서 `application/activity+json`은 `SHOULD` equivalent 해석 대상

실용적인 구현안:

- 최소한 위 두 타입은 허용
- 그 외 타입은 `415 Unsupported Media Type` 또는 `422`가 아니라 더 명확한 실패 코드로 거절

추가 기록:

- 실서비스 상호운용성을 고려하면 `application/json`까지 허용하고 싶어질 수 있다
- 하지만 기본 동작을 바로 넓히면 비표준 구현을 조용히 허용하게 된다
- 따라서 현재 방침은:
  - 기본은 `application/ld+json; profile=...` 와 `application/activity+json`만 허용
  - `application/json` 허용은 필요 시 설정 옵션으로 분리하여 검토
  - 옵션을 추가한다면 기본값은 `false`로 두는 것이 적절하다

### 구현 후보 파일

- `app/controllers/federails/server/activities_controller.rb`
- `spec/acceptance/federails/server/activities_controller_spec.rb`
- `spec/dummy/spec/requests/federation/inbox_note_for_post_spec.rb`
- `spec/dummy/spec/requests/federation/inbox_note_for_comment_spec.rb`

### 테스트 항목

- ActivityPub `Content-Type` 요청은 성공
- `application/activity+json` 요청은 성공
- `application/json` 요청은 실패
- 실패 시 상태 코드와 body 형식 확인

### 후속 검토 메모

- 향후 특정 ActivityPub 구현체가 실제로 `application/json`으로 inbox POST를 보내는 사례가 확인되면, 호환성 옵션 추가를 검토한다
- 그 경우에도 기본 동작은 유지하고 opt-in 설정으로만 여는 것이 바람직하다

## 작업 2. Federation GET의 Accept 정책 명확화 및 구현

### 관련 RFC

- `3.2` ActivityPub object retrieval 시 client는 ActivityPub `Accept`를 사용해야 함
- server는 ActivityPub representation을 제공해야 함

### 현재 상태

- request spec들은 모두 올바른 `Accept`를 사용함
- 엔진이 잘못된 `Accept`에 대해 어떤 동작을 해야 하는지는 명확히 고정되어 있지 않음
- 실제 동작은 Rails content negotiation에 많이 의존함

### 구현 목표

federation GET 엔드포인트의 `Accept` 정책을 명시적으로 정한다.

대상 엔드포인트:

- actor
- followers
- following
- outbox
- activity show
- published object

### 정책 옵션

옵션 A. 엄격 모드

- ActivityPub `Accept`가 아니면 `406 Not Acceptable`

옵션 B. 관용 모드

- ActivityPub `Accept`가 아니어도 fallback 허용
- 단, 문서에 “Federails는 호환성을 위해 관용적으로 처리한다”를 명시

권장:

- federation 전용 엔드포인트이므로 엄격 모드가 RFC 친화적이다
- 다만 기존 host app 사용성에 영향이 있으면 관용 모드를 선택할 수 있다

### 구현 후보 파일

- `app/controllers/federails/server_controller.rb`
- 각 request spec
- acceptance spec

### 테스트 항목

- 올바른 `Accept`면 정상 응답
- `application/activity+json` 허용 여부 확인
- 잘못된 `Accept`면 `406` 또는 정책상 정한 fallback 확인

## 권장 실행 순서

1. 작업 1
2. 작업 2

이 순서를 권장하는 이유:

- media type / accept 정책은 기존 federation 엔드포인트 계약을 먼저 고정하는 작업이다
- 둘 다 현재 범위 안에서 바로 구현 가능한 MUST 정리 작업이다

## 구현 시 주의사항

- `report.md`의 MUST를 전부 바로 구현 대상으로 보지 말 것
- shared inbox 관련 MUST는 shared inbox 기능 도입 시점에 같이 처리할 것
- liked / likes / shares collection MUST도 해당 기능 도입 시점에 처리할 것
- 현재 passing 중인 inbox/notifier 관련 MUST 테스트를 깨지 않도록 회귀 테스트를 먼저 보강할 것

## 완료 기준

다음을 만족하면 이번 계획 범위는 완료로 본다.

- inbox POST가 비-ActivityPub media type을 거절한다
- federation GET의 `Accept` 정책이 테스트와 문서로 고정된다
- 관련 request/acceptance/lib spec이 모두 통과한다
