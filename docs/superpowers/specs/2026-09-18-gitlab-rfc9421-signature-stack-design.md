# GitLab RFC9421 서명 스택 이식

> 로컬 `main`이 GitLab `fedipub/fedipub`의 RFC9421/Linzer 서명 스택과 갈라진 상태를
> GitLab 쪽으로 맞추되, 로컬 전용 계약은 어댑터로 유지한다.

공통 조상: `ed51c41`. GitLab tip: `6d4e661`. 로컬 HEAD는 이미 `ed51c41`까지 머지한 상태다.

---

## Decisions

- **RFC9421 서명 스택은 GitLab을 따른다.** 로컬 OpenSSL 수작업 RFC9421보다 업스트림 Linzer 구현을 채택한다.
- **범위는 HTTP+서명 전부 + 로컬 추가 기능 어댑터.** JsonRequest 싱글톤, double-knock, GET 서명을 가져오고, `verify_request!` → Actor, `verify_signatures` 토글, `PermanentDeliveryError`, Authorized Fetch는 어댑터로 유지한다.
- **application actor를 이번 작업에 포함한다.** GitLab GET 기본 서명과 동일하게 instance actor 키로 GET을 서명한다.
- **application actor 공개 면은 FEP 전부.** 레코드+키, webfinger (FEP-d556), nodeinfo (FEP-2677), 다른 actor의 `generator`와 application actor의 `implements` (FEP-844e). Jbuilder 변경은 Alba로 포팅한다.
- **GitLab 커밋 추적은 merge로 유지한다.** 파일 복사는 SHA가 끊기므로 `gitlab/main`을 한 번에 머지한다. 서명 스택 파일은 GitLab 쪽을 취하고, 로컬 어댑터·Alba FEP는 머지 이후 커밋으로 얹는다. `a175b75`부터 `6d4e661`까지 83커밋이 조상이 된다.
- **이식 수단은 A(최종 동작) + merge(히스토리).** 83커밋을 손으로 하나씩 맞추지 않는다. 충돌 정책으로 GitLab 최종 계약을 취한다.

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
| 로컬 | Alba 시리얼라이저 (삭제된 Jbuilder 복구 금지), Sorbet/RBS, `pagy`(kaminari 복구 금지), `DeliveryError` 계층 |
| 머지 후 커밋 | 로컬 어댑터 + FEP 필드를 Alba에 포팅 + GitLab 파일에 인라인 RBS |

송신: `JsonRequest`가 RFC9421로 서명하고, 400/401이면 draft-cavage-12로 한 번 더 보낸다. GET 기본 서명자는 `Fedipub::Actor.application_actor`.

수신: `Signature.verify!`가 Rfc9421 → Cavage 순으로 검사한다. inbox 미들웨어는 기존처럼 `verify_request!`를 호출한다. 어댑터가 `verify!(request:, require_signature: true)` 뒤 keyId로 Actor를 조회해 반환한다. GitLab 검증 경로가 이미 Actor를 찾지만, 업스트림 `verify!` API(bool)를 유지하기 위해 어댑터에서 한 번 더 조회한다.

`Signature.signed_get`은 제거한다. Authorized Fetch는 `JsonRequest.get(from:)`.

### 로컬 어댑터 경계

- `Fediverse::Signature.verify_request!(request)` → Actor. `BadSignature`를 `SignatureVerificationError`로 변환.
- `Fediverse::Notifier#post_to_inbox` → `JsonRequest.post` 후 HTTP 상태를 `DeliveryError` 계층으로 매핑. `NotifyInboxJob`은 그대로.
- `Fediverse::Webfinger` Authorized Fetch → `JsonRequest.get`.
- Alba: `ActorResource`에 application actor `implements`와 일반 actor `generator`. `WebFingerResource` / nodeinfo 리소스에 FEP-d556 / FEP-2677 링크.

---

## Error handling

GitLab `BadSignature`는 암호 계층 예외로 둔다. inbox `VerifySignature`는 계속 `SignatureVerificationError`를 rescue한다.

`Fedipub::Configuration.verify_signatures`가 true이면 서명 없는 inbox POST는 401이다. GitLab `verify!` 기본값(`require_signature: false`)은 서명 없는 요청을 통과시키므로, 로컬 보안 계약을 위해 어댑터는 `require_signature: true`를 넘긴다. 설정이 false이면 검증을 건너뛴다.

배달 매핑은 기존과 같다. 4xx(429 제외) → `PermanentDeliveryError`, 그 외 실패·네트워크 오류 → `TemporaryDeliveryError`.

서명 실패 로그는 기존 구조화 payload(`remote_ip`, `Signature-Input`, payload actor)를 유지한다.

---

## Testing

가져올 스펙: GitLab `spec/lib/fediverse/signature/rfc9421_spec.rb`, `draft_cavage12_spec.rb`, `spec/lib/fedipub/utils/json_request_spec.rb`, `spec/models/concerns/fedipub/application_actor_spec.rb`.

유지·수정할 스펙:

- `inbox_signature_spec`: `sign`이 Faraday 요청을 반환하므로 RFC9421 헤더(`Signature`, `Signature-Input`)로 다시 만든다. unsigned → 401, actor mismatch, 실패 로그 예제는 남긴다.
- `notifier_spec` 배달 에러: `JsonRequest.post` 응답 매핑을 검증한다.
- webfinger Authorized Fetch: `JsonRequest.get`을 쓰도록 바꾼다.
- Alba 시리얼라이저 스펙: `generator` / `implements` / webfinger·nodeinfo application actor 링크.

서명된 GET으로 VCR 카세트가 달라지면 재녹음한다. GitLab에서 가져온 Ruby 파일은 `bin/srb tc`가 통과하도록 인라인 RBS를 붙인다. Cavage 수신은 GitLab `draft_cavage12` 스펙으로 커버한다.

---

## Non-goals

- GitLab Jbuilder 템플릿을 되살리지 않는다.
- `kaminari`를 다시 넣지 않는다. 페이지네이션은 `pagy`를 유지한다.
- `verify!`가 Actor를 반환하도록 업스트림 API를 바꾸지 않는다.
- RFC9421 이외의 키 알고리즘을 추가하지 않는다. GitLab과 같이 `rsa-v1_5-sha256`만 쓴다.
- 이번 머지에 들어오지 않은 GitLab 이후 커밋은 다루지 않는다. tip은 `6d4e661`이다.

---

## Success

- `git merge-base HEAD gitlab/main`이 `6d4e661`이거나 gitlab/main이 HEAD의 조상이다.
- `git log -- lib/fediverse/signature/rfc9421.rb`에 GitLab 저자 커밋이 보인다.
- 서명된 GET/POST가 RFC9421이고, 400/401이면 cavage로 재시도한다.
- `verify_signatures: true`에서 unsigned inbox는 401이다.
- application actor가 생기고, webfinger/nodeinfo/actor JSON에 FEP 필드가 Alba로 나간다.
- 관련 spec과 `bin/srb tc`가 통과한다.
