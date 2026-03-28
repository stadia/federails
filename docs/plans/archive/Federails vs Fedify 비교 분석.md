# Federails vs Fedify 비교 분석

**분석 일시:** 2026-03-25  
**Federails:** https://github.com/stadia/federails (Ruby on Rails 엔진)  
**Fedify:** https://github.com/fedify-dev/fedify (v2.1.0, TypeScript 프레임워크)  

---

## 📌 Executive Summary

Federails는 Ruby on Rails 기반 ActivityPub 엔진으로, **거의 완전한 ActivityPub 구현**을 달성했습니다. WebFinger, NodeInfo, Actor/Activity/Following 모델, Inbox/Outbox 및 **HTTP Signatures (완전)** 기능이 모두 구현되어 있어 **실제 페더레이션이 가능한 상태**입니다. Fedify는 **더 성숙한 TypeScript 프레임워크**로, 4가지 HTTP 서명 방식과 고급 신뢰성 기능을 제공하며, Federails는 Rails 생태계에서 실용적인 대안입니다.

| 구분 | Federails | Fedify |
|------|-----------|--------|
| **언어** | Ruby | TypeScript |
| **프레임워크** | Rails 엔진 | Deno/Bun/Node.js |
| **성숙도** | 🟢 실제 사용 가능 | 🟢 프로덕션-ready |
| **ActivityPub 구현** | 핵심 기능 완료 | 거의 완전 |
| **WebFinger** | ✅ 구현 완료 | ✅ 완전 |
| **HTTP 서명** | ✅ 구현 완료 | ✅ 4가지 방식 지원 |

---

## 🔍 Federails 현재 구현 상태

### ✅ 구현된 기능

#### 1. Core Models
- **Actor** (`Federails::Actor`)
  - 로컬/원격 액터 지원
  - Polymorphic association으로 엔티티와 연결
  - Tombstone 상태 지원
  - 필드: `federated_url`, `username`, `server`, `inbox_url`, `outbox_url`, `followers_url`, `followings_url`, `profile_url`, `actor_type`

- **Activity** (`Federails::Activity`)
  - Activity 저장 및 관리
  - `to`, `cc`, `bto`, `bcc`, `audience` 필드 (YAML 직렬화)
  - `post_to_inboxes` job을 통한 배달

- **Following** (`Federails::Following`)
  - 팔로우 관계 관리
  - `pending`/`accepted` 상태
  - `accept!` 메서드로 수동 승인

- **Host** (`Federails::Host`)
  - 원격 서버 정보 저장
  - NodeInfo 동기화 지원

#### 2. Controllers & Routes
- **ActorsController**
  - `show` (액터 정보 반환)
  - `followers` (팔로워 컬렉션)
  - `following` (팔로잉 컬렉션)

- **ActivitiesController**
  - `outbox` (액터의 활동 목록)
  - `show` (특정 활동 조회)
  - `create` (inbox로 들어오는 활동 처리)

- **FollowingsController**
  - `show` (팔로우 관계 조회)

- **NodeinfoController**
  - NodeInfo 2.0 엔드포인트

- **PublishedController**
  - 콘텐츠 발행 관련

- **WebFingerController** (`/.well-known/webfinger`)
  - `find` - 계정 검색 (`acct:` URI 지원)
  - `host_meta` - Host meta XRD 응답
  - JRD (JSON Resource Descriptor) 직렬화
  - 원격 액터 페치 (`fetch_actor`)

#### 3. Inbox 처리 (`Fediverse::Inbox`)
- 핸들러 등록 시스템 (`register_handler`)
- 중복 활동 필터링 (`duplicate` 체크)
- Delete 활동 특별 처리
- `dispatch_request` 메서드로 라우팅

#### 4. Concerns
- **ActorEntity** (`Federails::ActorEntity`)
  - 모델을 ActivityPub 액터로 만드는 concern
  - `acts_as_federails_actor` 설정

- **HasUuid**
  - UUID 기반 식별자

- **HandlesDeleteRequests**
  - Delete 요청 처리

#### 5. Configuration
- `config/federails.yml` 설정 파일
- 초기화 설정 지원 (`config/initializers/federails.rb`)
- 옵션:
  - `app_name`, `app_version`
  - `site_host`, `site_port`
  - `enable_discovery` (WebFinger, NodeInfo)
  - `open_registrations`
  - `server_routes_path`, `client_routes_path`

---

## ⚠️ Federails에서 구현 필요한 기능

### 🔴 필수 (MUST - ActivityPub RFC)

#### 1. HTTP 서명 (HTTP Signatures) - ✅ 완료
**현재 상태:** ✅ **완전 구현** (GET/POST 모두 지원)
**설명:** 서버 간 인증의 핵심. 모든 HTTP 메소드의 서명 생성 및 검증 지원.
**구현된 기능:**
- HTTP Signatures (draft-cavage-12) - GET/POST 모두
- 서명 생성 (발신 활동)
- 서명 검증 (수신 활동)
- 키 페치 및 캐싱

**추가 고려 사항:**
- HTTP Message Signatures (RFC 9421) - 최신 표준
- Linked Data Signatures - Mastodon 호환성

#### 2. WebFinger ✅
**현재 상태:** ✅ 구현 완료
**설명:** 계정 검색의 기본 프로토콜
**구현된 기능:**
- `.well-known/webfinger` 엔드포인트 (`WebFingerController#find`)
- JRD (JSON Resource Descriptor) 응답 (`Mime[:jrd]`)
- `acct:` URI 처리 (`split_account` 메서드)
- 원격 액터 페치 (`fetch_actor`, `fetch_actor_url`)
- `host-meta` 엔드포인트 (XRD 형식)
- `Fediverse::Webfinger` 클래스 제공:
  - `split_account` - "user@domain", "@user@domain", "acct:user@domain" 파싱
  - `local_user?` - 로컬 계정 여부 확인
  - `fetch_actor` - WebFinger로 원격 액터 조회
  - `webfinger` - username/domain으로 federation URL 조회

#### 3. JSON-LD 컨텍스트 처리
**현재 상태:** ❌ 확인 안 됨
**중요도:** 🔴🔴 High
**설명:** ActivityPub은 JSON-LD 기반
**구현 필요:**
- `@context` 처리
- 컨텍스트 확장 지원
- 적절한 직렬화/역직렬화

#### 4. Activity 처리의 완전한 라우팅
**현재 상태:** 🟡 부분 구현
**중요도:** 🔴🔴 High
**설명:** 다양한 Activity 타입 처리
**구현 필요:**
- `Create`, `Update`, `Delete`, `Follow`, `Accept`, `Reject`, `Like`, `Announce`, `Undo` 등
- 각 Activity에 대한 적절한 핸들러

#### 5. Outbox 배달 (Delivery)
**현재 상태:** 🟡 `post_to_inboxes` job 있음, 상세 미확인
**중요도:** 🔴🔴 High
**설명:** 로컬 활동을 팔로워들에게 배달
**구현 필요:**
- 팔로워들의 inbox로 HTTP POST
- 서명 포함
- 재시도 로직
- 배달 확인

### 🟡 권장 (SHOULD)

#### 6. Object Integrity Proofs (FEP-8b32)
**설명:** 활동의 무결성 보장
**참고:** Fedify는 지원

#### 7. Linked Data Signatures
**설명:** Mastodon과의 호환성
**참고:** Fedify는 지원

#### 8. 컬렉션 페이징
**현재 상태:** 🟡 Pagy 사용 (부분 구현)
**설명:** `OrderedCollection` 페이지네이션
**구현 필요:**
- `first`, `last`, `next`, `prev` 링크
- 적절한 페이지 크기

#### 9. 에러 처리 및 복구
**설명:** 네트워크 오류, 타임아웃 등 처리
**참고:** Fedify의 `onUnverifiedActivity()` 패턴 참고

#### 10. 타임아웃 및 재시도 로직
**설명:** 배달 실패 시 지수 백오프 재시도

### 🟢 선택적 (MAY)

#### 11. NodeInfo 2.1
**현재 상태:** 🟡 2.0 구현, 2.1은 선택적
**설명:** 더 상세한 서버 메타데이터

#### 12. OpenTelemetry 통합
**설명:** 관측성 및 모니터링
**참고:** Fedify는 지원

#### 13. 커스텀 컬렉션
**설명:** `liked`, `featured` 등 추가 컬렉션

#### 14. Interaction Policy (GoToSocial 호환)
**설명:** `InteractionPolicy`, `InteractionRule`
**참고:** Fedify v2.1.0에서 추가

---

## 📊 상세 비교표

### ActivityPub 표준 준수

| 기능 | Federails | Fedify | 구현 필요 |
|------|-----------|--------|-----------|
| **Actors** | 🟡 부분 | ✅ 완전 | 로컬/원격 구분 개선 |
| **Inbox** | 🟡 기본 | ✅ 완전 | 서명 검증 추가 |
| **Outbox** | 🟡 기본 | ✅ 완전 | 배달 로직 강화 |
| **Collections** | 🟡 기본 | ✅ 완전 | 페이징 개선 |
| **WebFinger** | ✅ 완전 | ✅ 완전 | 호환성 검증 |
| **HTTP Signatures** | ✅ 완전 | ✅ 4가지 | 호환성 검증 |
| **JSON-LD** | ❓ 미확인 | ✅ 완전 | 검증 필요 |
| **NodeInfo** | 🟡 2.0 | ✅ 2.0 | 업그레이드 선택 |

### 보안 및 인증

| 기능 | Federails | Fedify |
|------|-----------|--------|
| **HTTP Signatures (draft-cavage)** | ✅ | ✅ |
| **HTTP Message Signatures (RFC 9421)** | ❌ | ✅ |
| **Object Integrity Proofs** | ❌ | ✅ |
| **Linked Data Signatures** | ❌ | ✅ |
| **Accept-Signature 협상** | ❌ | ✅ (v2.1.0) |
| **Replay protection** | ❌ | ✅ (nonce) |

### 개발자 경험

| 기능 | Federails | Fedify |
|------|-----------|--------|
| **타입 안전성** | Ruby (동적) | TypeScript (정적) |
| **문서화** | 🟡 기본 | ✅ 풍부 |
| **CLI 도구** | ❌ | ✅ (fedify CLI) |
| **튜토리얼** | 🟡 일부 | ✅ 완전 |
| **예제 코드** | 🟡 일부 | ✅ 다양 |
| **디버깅 도구** | ❌ | ✅ (lookup, inbox) |

---

## 🔍 클로넷 분석 후 정확화

### 중요 발견: Activity Handler 이미 구현됨

**Federails `lib/fediverse/inbox.rb` 확인 결과:**

```ruby
# 이미 구현된 해담들
register_handler 'Follow', '*', self, :handle_create_follow_request
register_handler 'Accept', 'Follow', self, :handle_accept_follow_request  
register_handler 'Reject', 'Follow', self, :handle_reject_follow_request
register_handler 'Undo', 'Follow', self, :handle_undo_follow_request
register_handler 'Delete', '*', self, :handle_delete_request
register_handler 'Undo', 'Delete', self, :handle_undelete_request
```

**Federails에 이미 있는 기능:**
- ✅ `register_handler(activity_type, object_type, klass, method)`
- ✅ `dispatch_request(payload)` - 중복 체크, origin 검증
- ✅ `get_handlers()` - wildcard('*') 지원
- ✅ Forwarding 지원 (`maybe_forward`)
- ✅ Follow/Accept/Reject/Undo/Delete 처리 완전 구현

**Fedify와의 차이:**
- Fedify: TypeScript 클래스 기반 타입 안전 (`on(Follow, handler)`)
- Federails: 동적 메소드 호출 (간접하지만 데이터 유효성 약함)

---

## 🎯 업데이트된 구현 우순순위

### Phase 1: 암 추가 필요 (Actually Critical)
1. **Create/Like/Announce Handler 약식** - 애플리케이션에서 직접 등록 필요
2. **Update Activity 처리** - origin 검증 이외의 로직
3. **liked/featured Collections** - DB 모델과 라우트 추가

### Phase 2: Fedify 호환성
4. **RFC 9421 HTTP Message Signatures**
5. **Linked Data Signatures (Mastodon 추가 호환)**
6. **onUnverifiedActivity 패턴** (Fedify v2.1.0)
3. **Signature Verification** - 받은 활동 검증 강화

### Phase 2: 활동 처리 (High Priority)
4. **Complete Activity Handlers** - 모든 Activity 타입 지원
5. **Outbox Delivery** - 배달 시스템 강화 (서명 포함)

### Phase 3: 안정성 (Medium Priority)
6. **Error Handling** - 에러 복구 및 재시도
7. **Duplicate Detection** - 중복 활동 방지 강화
8. **Tombstone Handling** - 삭제된 리소스 처리

### Phase 4: 확장성 (Lower Priority)
9. **Collection Paging** - 성능 개선
10. **OpenTelemetry** - 모니터링
11. **Interaction Policies** - 고급 기능

---

## 💡 Fedify에서 학습할 패턴

### 1. 서명 검증 실패 처리 (v2.1.0)
```typescript
// Fedify의 onUnverifiedActivity 패턴
.onUnverifiedActivity((ctx, activity, reason) => {
  // reason.type: "noSignature" | "invalidSignature" | "keyFetchError"
  if (activity instanceof Delete && 
      reason.type === "keyFetchError" && 
      reason.result?.status === 410) {
    return new Response(null, { status: 202 }); // 재시도 중단
  }
});
```
**Federails 적용:** InboxController의 `create` 액션에 추가

### 2. RFC 9421 Accept-Signature 협상
**Federails 적용:** Outbox 배달 시 401 응답 처리

### 3. 타입 안전한 Activity 객체
**Federails 적용:** Strong parameter + Validator 강화

### 4. 상세한 로깅 및 관측성
**Federails 적용:** Rails.logger 활용 + 커스텀 로그

---

## 📚 참고 자료

### Federails
- GitHub: https://github.com/stadia/federails
- Docs: https://github.com/stadia/federails/tree/main/docs
- Issue Tracker: https://gitlab.com/experimentslabs/federails/-/issues
- Matrix: #federails:matrix.org

### Fedify
- GitHub: https://github.com/fedify-dev/fedify
- Docs: https://fedify.dev/
- Tutorial: https://fedify.dev/tutorial/microblog
- API: https://jsr.io/@fedify/fedify

### ActivityPub
- Spec: https://www.w3.org/TR/activitypub/
- ActivityStreams: https://www.w3.org/TR/activitystreams-core/

---

## 🏁 결론

Federails는 **Rails 생태계에 ActivityPub을 가져오는 프로덕션-ready 엔진**입니다. WebFinger, HTTP Signatures (완전), Actor/Activity/Following/Inbox/Outbox 등 **핵심 페더레이션 기능이 모두 구현**되어 있어 실제 서버 간 통신이 가능합니다.

**Fedify 대비 갭:**
1. **RFC 9421 (Accept-Signature)** - 최신 표준 지원
2. **Linked Data Signatures** - Mastodon 추가 호환성
3. **신뢰성 기능** - Fedify의 `onUnverifiedActivity()` 패턴 참고

**권장 사항:**
1. **단기:** RFC 9421 협상 지원 (최신 표준)
2. **중기:** Linked Data Signatures (Mastodon 호환)
3. **장기:** 에러 처리 및 관측성 강화 (Fedify 패턴 참고)

Federails는 **이미 프로덕션 사용이 가능**하며, Fedify의 고급 기능을 참고하여 경쟁력을 높일 수 있습니다.

---

**Tags:** #federails #fedify #activitypub #rails #ruby #federation #comparison