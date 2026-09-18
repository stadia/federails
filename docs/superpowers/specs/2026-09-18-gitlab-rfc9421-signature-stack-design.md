# GitLab RFC9421 서명 스택 이식

> 로컬 `main`이 GitLab `fedipub/fedipub`의 RFC9421/Linzer 서명 스택과 갈라진 상태를
> GitLab 쪽으로 맞춘다. **프로토콜(HTTP Signature, ActivityPub 바이트, FEP)의 기준은 GitLab**이다.
> 로컬 어댑터는 프로토콜을 바꾸지 않는 운영 계약(잡 재시도, 타입, 시리얼라이저 라이브러리)에만 쓴다.

공통 조상: `ed51c41`. GitLab tip: `6d4e661`. 로컬 HEAD는 이미 `ed51c41`까지 머지한 상태다.

---

## Decisions

- **RFC9421 서명 스택은 GitLab을 따른다.** 로컬 OpenSSL 수작업 RFC9421보다 업스트림 Linzer 구현을 채택한다.
- **프로토콜 구현의 기준은 GitLab이다.** 헤더, 서명 알고리즘, 검증 순서, application actor FEP, 서명 유무에 따른 수신 동작은 업스트림과 같게 둔다. 로컬에서 프로토콜을 더 엄격하게 만들지 않는다.
- **범위는 HTTP+서명 전부 + 비프로토콜 어댑터.** JsonRequest 싱글톤, double-knock, GET 서명, `ServerController`의 `verify_request_signature!`를 가져온다. `PermanentDeliveryError`와 Alba는 프로토콜 JSON이 GitLab과 동등한 한 유지한다.
- **application actor를 이번 작업에 포함한다.** GitLab GET 기본 서명과 동일하게 instance actor 키로 GET을 서명한다.
- **application actor 공개 면은 FEP 전부.** 레코드+키, webfinger (FEP-d556), nodeinfo (FEP-2677), 다른 actor의 `generator`와 application actor의 `implements` (FEP-844e). Jbuilder 변경은 Alba로 포팅하되 **나가는 JSON 필드는 GitLab과 같게** 한다.
- **GitLab 커밋 추적은 merge로 유지한다.** 파일 복사는 SHA가 끊기므로 `gitlab/main`을 한 번에 머지한다. 서명 스택 파일은 GitLab 쪽을 취하고, 로컬 어댑터·Alba FEP는 머지 이후 커밋으로 얹는다. `a175b75`부터 `6d4e661`까지 83커밋이 조상이 된다.
- **이식 수단은 A(최종 동작) + merge(히스토리).** 83커밋을 손으로 하나씩 맞추지 않는다. 충돌 정책으로 GitLab 최종 계약을 취한다.
- **`require_signature?` 기본값은 GitLab과 같이 false로 둔다.** RFC 9421은 깨진 서명만 거부하면 되고, ActivityPub S2S는 HTTP Signature를 MUST로 두지 않는다. unsigned inbox를 로컬에서 401로 조이지 않는다. 서명이 있으면 검증하고, 깨지면 401이다.

---

## Problem

공통 조상의 `Fediverse::Signature` 클래스를 양쪽이 재작성했다.

- 로컬: 클래스 유지, `sign` → 헤더 String, `verify_request!` → Actor, Notifier가 서명 POST, `Signature.signed_get`으로 Authorized Fetch.
- GitLab: 모듈 + `DraftCavage12`/`Rfc9421` + Linzer, `sign` → Faraday Request, `JsonRequest` 싱글톤이 GET/POST와 double-knock를 담당, GET 기본 서명자는 application actor.

텍스트 충돌보다 계약 불일치가 핵심이다. `a175b75`만 머지해도 `signature.rb`와 `signature_spec.rb`가 충돌한다.

---

## Architecture

`git merge gitlab/main`으로 남은 83커밋을 조상으로 남긴다. 이 머지는 서명 스택만이 아니라 GitLab 쪽 해당 구간의 비충돌 파일도 함께 들어온다. 충돌 파일만 아래 정책으로 고른다.

| 취할 쪽 | 대상 |
|---|---|
| GitLab | `lib/fediverse/signature.rb`, `lib/fediverse/signature/*`, `lib/fedipub/utils/json_request.rb`, `app/models/concerns/fedipub/application_actor.rb`, `linzer` gem, GitLab 서명/application actor 스펙 |
| 로컬 (비프로토콜) | Alba 시리얼라이저 (삭제된 Jbuilder 복구 금지, **JSON 필드는 GitLab과 동등**), Sorbet/RBS, `pagy`(kaminari 복구 금지), `DeliveryError` 계층 |
| 머지 후 커밋 | 비프로토콜 어댑터 + FEP 필드를 Alba에 포팅 + GitLab 파일에 인라인 RBS |

송신: `JsonRequest`가 RFC9421로 서명하고, 400/401이면 draft-cavage-12로 한 번 더 보낸다. GET 기본 서명자는 `Fedipub::Actor.application_actor`. `Accept-Signature`와 User-Agent/`Accept` 기본값도 GitLab과 같다.

수신: GitLab `ServerController#verify_request_signature!`가 기준이다. `Signature.verify!(request:, require_signature: ServerController.require_signature?)`를 쓰고, 기본 `require_signature?`는 **false**다. 서명이 있으면 Rfc9421 → Cavage로 검증하고 실패 시 401. **서명이 없으면 통과**한다. 로컬 어댑터로 `require_signature: true`를 강제하지 않는다.

`Signature.signed_get`은 제거한다. Authorized Fetch는 GitLab과 같이 `JsonRequest.get`(application actor 기본 서명).

로컬 `VerifySignature#verify_request!` → Actor는, GitLab이 `@signed_actor`를 주지 않는 호출부(payload actor 대조 등)를 위한 **추가 조회**일 뿐이다. 검증 성공/실패 판정은 GitLab `verify!`와 같아야 한다.

### 로컬 어댑터 경계 (프로토콜 밖)

- `Fediverse::Notifier#post_to_inbox` → `JsonRequest.post` 후 HTTP 상태를 `DeliveryError` 계층으로 매핑. `NotifyInboxJob`은 그대로. 보내는 요청의 서명/헤더는 GitLab `JsonRequest` 그대로.
- Alba: GitLab Jbuilder가 내던 FEP 필드를 같은 키로 낸다. `ActorResource` `implements`/`generator`, webfinger·nodeinfo application actor 링크.
- 인라인 RBS / Sorbet: 동작 변경 없이 타입만.

---

## Error handling

암호 계층 예외는 GitLab `BadSignature`다. `ServerController`는 이를 401로 바꾼다. 로컬 `SignatureVerificationError`는 `BadSignature`의 별칭이거나, 같은 실패를 감싸는 호환 레이어로만 둔다. 실패 조건은 GitLab과 같아야 한다.

서명 없는 서버 요청은 401이 아니다. 잘못된 서명·keyId 조회 실패만 401이다. `Fedipub::Configuration.verify_signatures = false`는 테스트용 킬 스위치로 남을 수 있지만, true일 때도 GitLab과 같이 “있으면 검증, 없으면 통과”이다.

배달 매핑은 기존과 같다. 4xx(429 제외) → `PermanentDeliveryError`, 그 외 실패·네트워크 오류 → `TemporaryDeliveryError`. 이는 잡 재시도 정책이지 페더레이션 프로토콜이 아니다.

서명 실패 로그의 구조화 payload(`remote_ip`, `Signature-Input`, payload actor)는 로컬 관측성으로 유지해도 된다.

---

## Testing

가져올 스펙: GitLab `spec/lib/fediverse/signature/rfc9421_spec.rb`, `draft_cavage12_spec.rb`, `signature_spec.rb`, `spec/lib/fedipub/utils/json_request_spec.rb`, `spec/models/concerns/fedipub/application_actor_spec.rb`, 그리고 GitLab이 `require_signature?`를 스텁하는 request 스펙의 서명 동작.

유지·수정할 스펙:

- `inbox_signature_spec`: RFC9421 헤더로 다시 만든다. **unsigned는 통과**가 GitLab과 맞다. 잘못된 서명은 401. actor mismatch는 GitLab에 없는 로컬 정책이면 별도 예제로 남기되, unsigned 401 예제는 제거하거나 GitLab 동작에 맞게 고친다.
- `notifier_spec` 배달 에러: `JsonRequest.post` 응답 매핑을 검증한다. 요청이 RFC9421로 서명되는지는 GitLab json_request 스펙이 담당한다.
- webfinger: GitLab FEP-d556 링크 + 서명된 GET(`JsonRequest.get`).
- Alba 시리얼라이저 스펙: GitLab Jbuilder와 같은 `generator` / `implements` / webfinger·nodeinfo 필드.

서명된 GET으로 VCR 카세트가 달라지면 재녹음한다. GitLab에서 가져온 Ruby 파일은 `bin/srb tc`가 통과하도록 인라인 RBS를 붙인다.

---

## Non-goals

- GitLab Jbuilder 템플릿을 되살리지 않는다. JSON 동등성이 목표다.
- `kaminari`를 다시 넣지 않는다. 페이지네이션은 `pagy`를 유지한다.
- `verify!`가 Actor를 반환하도록 업스트림 API를 바꾸지 않는다.
- RFC9421 이외의 키 알고리즘을 추가하지 않는다. GitLab과 같이 `rsa-v1_5-sha256`만 쓴다.
- 서명 없는 inbox를 로컬에서 401로 조이지 않는다.
- 이번 머지에 들어오지 않은 GitLab 이후 커밋은 다루지 않는다. tip은 `6d4e661`이다.

---

## Success

- `gitlab/main`(`6d4e661`)이 HEAD의 조상이다.
- `git log -- lib/fediverse/signature/rfc9421.rb`에 GitLab 저자 커밋이 보인다.
- 나가는 GET/POST 서명, double-knock, application actor FEP JSON이 GitLab과 같다 (라이브러리만 Alba).
- 들어오는 요청은 서명이 있으면 검증하고, 없으면 통과한다. 잘못된 서명은 401이다.
- 관련 spec과 `bin/srb tc`가 통과한다.
