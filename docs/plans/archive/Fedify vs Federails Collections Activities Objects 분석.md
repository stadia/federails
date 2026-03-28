# Fedify vs Federails 상세 분석 - Collections, Activities, Objects

**분석 일시:** 2026-03-25  
**목적:** Collections, Activities, Objects 구현 강화 방안

---

## 📊 핵심 갭 분석 요약

| 영역 | Fedify | Federails | 강화 필요도 |
|------|--------|-----------|------------|
| **Collections** | 완전 (built-in + custom) | 기본 (followers/following만) | 🔴 높음 |
| **Activities** | 타입 안전 + 핸들러 완전 | 기본 저장/라우팅 | 🔴 높음 |
| **Objects** | 타입 안전 + 유효성 검사 | 기본 JSON-LD | 🟡 중간 |
| **Activity Vocabulary** | 완전 구현 | 부분 구현 | 🔴 높음 |

---

## 1️⃣ Collections (컬렉션)

### 현재 Federails 상태
```ruby
# app/controllers/federails/server/actors_controller.rb
def followers
  @actors = @actor.followers.order(created_at: :desc)
  # Pagy 사용, 기본 OrderedCollection
end
```

**구현된 것:**
- ✅ `followers` / `following` 컬렉션
- ✅ 기본 `OrderedCollection` 직렬화
- ✅ Pagy 기반 페이지네이션

**누락된 것 (Fedify 대비):**

#### 🔴 Custom Collections 지원
**Fedify는:**
```typescript
// 사용자 정의 컬렉션 생성 가능
federation.setOutboxDispatcher("/users/{id}/outbox", handler)
federation.setLikedDispatcher("/users/{id}/liked", handler)  // liked 컬렉션
federation.setFeaturedDispatcher("/users/{id}/featured", handler)  // featured
// 그 외 임의 컬렉션
```

**Federails 필요:**
- `liked` 컬렉션 (사용자가 좋아요한 객체들)
- `featured` 컬렉션 (사용자가 추천한 객체들)  
- 앱 특화 커스텀 컬렉션 지원
- 동적 컬렉션 등록 메커니즘

#### 🔴 Collection Paging 완전성
**Fedify는:**
```typescript
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://example.com/users/alice/outbox",
  "type": "OrderedCollection",
  "totalItems": 42,
  "first": "https://example.com/users/alice/outbox?page=1",
  "last": "https://example.com/users/alice/outbox?page=5",
  "current": "..."  // 현재 페이지
}
```

**Federails 필요:**
- `first`, `last` 링크 필수 포함
- `current` 페이지 표시 (선택)
- 페이지당 항목 수 설정 가능
- 컬렉션 메타데이터 완전성

#### 🟡 Collection Fetching
**Fedify:** 원격 컬렉션 자동 fetch 및 캐싱
```typescript
const collection = await ctx.fetchCollection(url)
```

**Federails:** `Fediverse::Collection.fetch` 있음 (basic)
```ruby
# lib/fediverse/collection.rb
class Collection < Array
  def fetch(url, max_pages: DEFAULT_MAX_PAGES)
    # 구현됨 - orderedItems/items 수집
  end
end
```

**강화 필요:**
- 캐싱 메커니즘 (Redis 등)
- 컬렉션 변경 감지 (etag, last-modified)
- 부분 업데이트 (delta sync)

---

## 2️⃣ Activities (활동)

### 현재 Federails 상태
```ruby
# app/models/federails/activity.rb
class Activity < ApplicationRecord
  belongs_to :entity, polymorphic: true
  belongs_to :actor
  # to, cc, bto, bcc, audience 필드 (YAML 직렬화)
end

# Inbox 처리
result = Fediverse::Inbox.dispatch_request(payload)
```

**구현된 것:**
- ✅ Activity 저장 (DB 모델)
- ✅ 기본 Inbox 라우팅
- ✅ `to`, `cc`, `bto`, `bcc`, `audience` 주소 지정
- ✅ 중복 체크 (`duplicate`)

**누락된 것 (Fedify 대비):**

#### 🔴 Type-Safe Activity Objects
**Fedify는:**
```typescript
import { Create, Delete, Follow, Accept, Reject, Like, Announce, Undo } from "@fedify/vocab"

// 각 Activity가 클래스로 구현
const activity = new Create({
  id: new URL("..."),
  actor: actorUri,
  object: new Note({...}),
  to: [publicCollection],
  cc: [followersCollection]
})
```

**Federails 필요:**
- `Create`, `Delete`, `Follow`, `Accept`, `Reject`, `Like`, `Announce`, `Undo` 등 Activity 타입 클래스
- 각 Activity의 유효성 검사 (필수 필드)
- Activity별 특화 로직 (예: Delete는 object 참조 해제)

#### 🔴 Activity Handlers 완전성
**Fedify는:**
```typescript
federation
  .setInboxListeners("/users/{id}/inbox", "/inbox")
  .on(Follow, async (ctx, follow) => { /* Follow 처리 */ })
  .on(Create, async (ctx, create) => { /* Create 처리 */ })
  .on(Delete, async (ctx, del) => { /* Delete 처리 */ })
  .on(Like, async (ctx, like) => { /* Like 처리 */ })
  // ... 모든 Activity 타입
```

**Federails 현재:**
```ruby
# lib/fediverse/inbox.rb - 부분 구현
def dispatch_request(payload)
  if payload['type'] == 'Delete'
    dispatch_delete_request(payload)
  end
  # 다른 Activity 타입은? 일반적 처리만
end
```

**필요:**
- Activity 타입별 핸들러 등록 시스템
- `register_handler` 활용한 완전한 라우팅
- 각 Activity의 side-effect 처리 (Follow → Following 생성 등)

#### 🔴 Activity Validation & Normalization
**Fedify:**
```typescript
// Activity 검증
activity.validate()  // 필수 필드 체크
// JSON-LD 정규화
activity.toJsonLd()  // 표준 형식
```

**Federails:**
```ruby
# ActivitiesController
def validate_payload(hash)
  return unless hash['@context'] && hash['id'] && hash['type'] && hash['actor'] && hash['object']
  hash
end
```

**강화 필요:**
- Activity Schema validation (json-schema?)
- 필수 필드 체크 강화
- `@context` 유효성 검사
- ID uniqueness 보장

#### 🟡 Activity Addressing (배달)
**Fedify:**
```typescript
// to, cc, bto, bcc, audience 자동 처리
// 공개/팔로워/특정 사용자 분류
ctx.sendActivity(recipients, activity)
```

**Federails:**
```ruby
# app/models/federails/activity.rb
def set_default_addressing
  self.to = [Fediverse::Collection::PUBLIC]
  self.cc = [actor.followers_url, entity.try(:followers_url)]
end
```

**강화 필요:**
- Addressing 계산 로직 완성 (Public, Followers, Specific)
- 배달 대상자 중복 제거
- 수신 거부 (block) 처리

---

## 3️⃣ Objects (객체)

### 현재 Federails 상태
```ruby
# JSON-LD compact 사용
JSON::LD::API.compact(payload, payload['@context'])

# 객체는 일반적으로 polymorphic entity로 저장
belongs_to :entity, polymorphic: true
```

**구현된 것:**
- ✅ JSON-LD compact/expand
- ✅ Polymorphic entity 연결
- ✅ 기본 객체 역참조 (dereference)

**누락된 것 (Fedify 대비):**

#### 🔴 Activity Vocabulary 객체
**Fedify는:**
```typescript
import { Note, Article, Image, Video, Page, Event, Place, Mention } from "@fedify/vocab"

// 각 객체 타입이 클래스로 구현
const note = new Note({
  id: new URL("..."),
  content: "<p>Hello</p>",
  attributedTo: actorUri,
  to: [publicCollection],
  attachment: [new Image({...})]  // 중첩 객체
})
```

**Federails 필요:**
```ruby
# app/models/federails/object/ 하위에 각 객체 타입
class Note < Object
  validates :content, presence: true
  # contentMap (다국어)
  # attachment
  # inReplyTo
end

class Article < Object
  # name, content
  # published, updated
end

class Image < Object
  # url, width, height
  # blurhash (Mastodon 호환)
end
# ... Video, Page, Event, Place 등
```

#### 🔴 Object Dereferencing & Caching
**Fedify:**
```typescript
// 객체 자동 fetch 및 캐싱
const object = await ctx.fetchObject(url)
```

**Federails:**
```ruby
# lib/fediverse/request.rb
def self.dereference(value)
  return value if value.is_a? Hash
  return get(value) if value.is_a? String
end
```

**강화 필요:**
- 객체 캐싱 (TTL 기반)
- 조건부 fetch (etag/if-none-match)
- 객체 무효화 (invalidation)
- 순환 참조 방지

#### 🔴 Object Validation
**Fedify:** 객체 타입별 유효성 검사
```typescript
note.validate()  // content 필수 등
```

**Federails 필요:**
- 객체 타입별 스키마 정의
- 필수 필드 검사
- MIME 타입 검증
- 크기 제한 (이미지/비디오)

#### 🟡 Object Metadata
**Fedify:**
```typescript
// published, updated, attributedTo, to, cc 등
// 원본 출처 (via, generator 등)
```

**Federails 필요:**
- 메타데이터 추출 및 저장
- 원본 출처 추적
- 페더레이션 경로 기록

---

## 4️⃣ 구체적 강화 방안

### Phase 1: 타입 시스템 구축 (핵심)

#### Activity Vocabulary 구현
```
app/models/federails/vocab/
  ├── activity/
  │   ├── base.rb
  │   ├── create.rb
  │   ├── delete.rb
  │   ├── follow.rb
  │   ├── accept.rb
  │   ├── reject.rb
  │   ├── like.rb
  │   ├── announce.rb
  │   └── undo.rb
  └── object/
      ├── base.rb
      ├── note.rb
      ├── article.rb
      ├── image.rb
      ├── video.rb
      ├── page.rb
      ├── event.rb
      ├── place.rb
      └── mention.rb
```

#### Handler 시스템
```ruby
# config/initializers/federails_handlers.rb
Federails::Inbox.register_handler(Follow, MyApp::FollowHandler, :process)
Federails::Inbox.register_handler(Create, MyApp::CreateHandler, :process)
# ...
```

### Phase 2: 컬렉션 강화

#### Custom Collections
```ruby
# app/models/federails/collection.rb
class Collection < ApplicationRecord
  # 사용자 정의 컬렉션 지원
  belongs_to :actor
  has_many :items, -> { ordered }
  
  # liked, featured 등 타입
  enum :collection_type, %i[custom liked featured bookmarks]
end
```

### Phase 3: 고급 기능

#### Object Integrity Proofs (FEP-8b32)
```ruby
# 객체 무결성 증명
class Activity
  def add_integrity_proof
    # FEP-8b32 구현
  end
end
```

#### Linked Data Signatures
```ruby
# Mastodon 호환성
class Signature
  def sign_ld(object)
    # JSON-LD 서명
  end
end
```

---

## 5️⃣ Fedify 패턴 적용 우선순위

| 우선순위 | 패턴 | 적용 위치 | 효과 |
|---------|------|----------|------|
| 🔴 P0 | Type-safe Activities | `app/models/federails/vocab/` | 안정성 ↑ |
| 🔴 P0 | Activity Handlers | `lib/federails/inbox.rb` | 기능 완성 |
| 🔴 P1 | Custom Collections | `app/models/federails/collection.rb` | 유연성 ↑ |
| 🟡 P2 | Object Caching | `lib/fediverse/request.rb` | 성능 ↑ |
| 🟡 P2 | Activity Validation | `app/controllers/federails/server/activities_controller.rb` | 신뢰성 ↑ |
| 🟢 P3 | Object Vocabulary | `app/models/federails/vocab/object/` | 완전성 ↑ |

---

## 📊 최종 평가

### 현재 Federails 점수 (Fedify = 10 기준)

| 영역 | 현재 | 목표 | 갭 |
|------|------|------|-----|
| Collections | 4/10 | 9/10 | 큼 |
| Activities | 5/10 | 9/10 | 큼 |
| Objects | 4/10 | 8/10 | 큼 |
| **총계** | **13/30** | **26/30** | **큰 개선 필요** |

### 핵심 결론

**Federails는 ActivityPub "기반"은 있으나, "완성"은 아님:**

✅ **잘된 것:**
- HTTP Signatures (GET/POST)
- WebFinger
- 기본 Inbox/Outbox
- Actor/Activity/Following 모델

🔴 **부족한 것:**
- **타입 안전한 Activity/Object 시스템** (가장 중요)
- **완전한 Activity 핸들러** (모든 타입 지원)
- **커스텀 컬렉션** (liked, featured 등)
- **객체 캐싱/검증**

**Fedify 참고 시 가장 큰 차이:**
> Fedify는 **타입 시스템과 핸들러 패턴**으로 robust함. Federails는 **ActiveRecord 중심**으로 단순하지만 유연성 부족.

---

---

## 🎯 해야 할 일 (Action Items)

### 🔴 필수 (P0) - 즉시 필요

#### 1. Activity Vocabulary 타입 시스템 구축
```
app/models/federails/vocab/
├── base.rb              # Base class with validations
├── activity.rb          # Activity base (actor, object, to, cc, etc.)
├── create.rb            # Create Activity
├── delete.rb            # Delete Activity  
├── follow.rb            # Follow Activity
├── accept.rb            # Accept Activity
├── reject.rb            # Reject Activity
├── like.rb              # Like Activity
├── announce.rb          # Announce (Boost) Activity
├── undo.rb              # Undo Activity
└── object/
    ├── base.rb          # Object base
    ├── note.rb          # Note (microblog)
    ├── article.rb       # Article (blog post)
    ├── image.rb         # Image with blurhash
    ├── video.rb         # Video with duration
    └── page.rb          # Web page
```

**핵심 요구사항:**
- 각 Activity/Object는 ActiveModel 기반
- `valid?` 메서드로 유효성 검사
- `to_json_ld` 메서드로 JSON-LD 직렬화
- 필수 필드 validation

#### 2. Activity Handler 라우팅 시스템
```
lib/federails/
├── activity_handler.rb  # Base handler class
└── handlers/
    ├── create_handler.rb
    ├── follow_handler.rb
    ├── like_handler.rb
    └── default_handler.rb
```

**핵심 요구사항:**
```ruby
# lib/fediverse/inbox.rb 개선
Federails::Inbox.register_handler('Create', MyApp::CreateHandler)
Federails::Inbox.register_handler('Follow', MyApp::FollowHandler)
# 모든 Activity 타입에 핸들러 등록
```

#### 3. Custom Collections 추가
```
app/models/federails/
├── collection.rb        # liked, featured, custom 지원
└── collection_item.rb   # Collection 내 아이템
```

**핵심 요구사항:**
```ruby
# Actor 모델에 추가
has_one :liked_collection
has_one :featured_collection

# 기본 제공 컬렉션
actor.create_liked_collection!    # /users/:id/liked
actor.create_featured_collection! # /users/:id/featured
```

### 🟡 중요 (P1) - 단기 필요

#### 4. JSON-LD 컨텍스트 처리 강화
- `@context` 유효성 검사
- 컨텍스트 확장 지원
- Mastodon 확장 컨텍스트 지원

#### 5. 객체 캐싱/최적화
```ruby
lib/fediverse/request.rb 개선:
- TTL 기반 캐싱 (Redis)
- etag/if-none-match 지원
- 순환 참조 방지
```

#### 6. Activity Addressing 완성
- `to`, `cc`, `bto`, `bcc`, `audience` 완전 계산
- Public/Followers/Specific 수신자 분류
- 배달 대상자 중복 제거

### 🟢 향후 (P2) - 선택적

#### 7. 고급 서명 지원
- HTTP Message Signatures (RFC 9421)
- Linked Data Signatures (Mastodon 호환)
- Object Integrity Proofs (FEP-8b32)

#### 8. 관측성/모니터링
- OpenTelemetry 통합
- 상세 로깅
- 메트릭 수집

---

## 📋 우선순위 요약

| 순위 | 작업 | 예상 시간 | 영향 |
|------|------|----------|------|
| 1 | Activity Vocabulary 타입 | 2-3일 | 🔴 크음 |
| 2 | Handler 라우팅 | 1-2일 | 🔴 크음 |
| 3 | Custom Collections | 1일 | 🔴 큼 |
| 4 | JSON-LD 강화 | 1일 | 🟡 중간 |
| 5 | 캐싱/최적화 | 1-2일 | 🟡 중간 |

**총 예상:** 1주일 내 완료 가능

---

**Tags:** #federails #fedify #activitypub #collections #activities #objects #vocabulary #todo