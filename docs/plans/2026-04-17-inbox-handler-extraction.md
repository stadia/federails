# Inbox Handler 모듈 분리 리팩터링 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `lib/fediverse/inbox.rb`(~383 LOC)에 혼재된 Follow/Delete 관련 핸들러 로직을 기존 `LikeHandler`/`AnnounceHandler`/`BlockHandler` 패턴을 따라 `FollowHandler`, `DeleteHandler` 모듈로 분리해 `Inbox` 본체는 디스패치·포워딩·공통 유틸만 담당하게 한다.

**Architecture:**
- `Fediverse::Inbox::FollowHandler`: 인바운드 `Follow` / `Accept` / `Reject` / `Undo Follow` 4개 핸들러 + Follow 전용 private 헬퍼(`inbound_follow_activity`, `dispatch_followed_callback`, `resend_accept_for_duplicate_follow`) 보유
- `Fediverse::Inbox::DeleteHandler`: `Delete` / `Undo Delete` 핸들러 + `dispatch_request`의 Delete 조기 분기 로직(`dispatch_delete_request`) 보유
- `Inbox` 본체: `dispatch_request` / `maybe_forward` / `register_handler` / `record_processed_activity` / 공통 URL·address 판정 유틸만 유지
- register 호출 시점은 기존 handler 파일들처럼 각 handler 파일 하단에서 `Fediverse::Inbox.register_handler(...)` 수행하여 로드 순서 의존성을 명확히 한다

**Tech Stack:** Ruby, RSpec, rbs-inline, Rails 7+

**Scope out:** `dispatch_delete_request`와 `handle_delete_request`의 기능 중복(현재도 `@@handlers['Delete']['*']`로 등록돼 있으나 이른 분기에서 선처리되는 구조)은 그대로 이관만 하고 코드 합치기는 이번 리팩터링 범위에서 제외한다. 행동 변경 없음을 목표로 한다.

---

## File Structure

**신규 파일**
- `lib/fediverse/inbox/follow_handler.rb` — Follow/Accept/Reject/Undo-Follow 핸들러 + Follow 전용 헬퍼
- `lib/fediverse/inbox/delete_handler.rb` — Delete/Undo-Delete 핸들러 + 이른 분기 로직
- `spec/lib/fediverse/inbox/follow_handler_spec.rb`
- `spec/lib/fediverse/inbox/delete_handler_spec.rb`
- `sig/generated/fediverse/inbox/follow_handler.rbs` (자동 생성)
- `sig/generated/fediverse/inbox/delete_handler.rbs` (자동 생성)

**수정 파일**
- `lib/fediverse/inbox.rb` — 이동된 메서드 제거, `require`/`register_handler` 업데이트, 이른 Delete 분기 위임
- `spec/lib/fediverse/inbox_spec.rb` — follow/delete 관련 `describe` 블록 제거
- `sig/generated/fediverse/inbox.rbs` — 자동 재생성
- `CHANGELOG.md` — 변경 사항 문서화
- `docs/plans/archive/Fedify vs Federails Collections Activities Objects 분석.md` 등 이전 참조 — 필요 시만 (archive 문서는 건드리지 않는다)

---

## Task 1: FollowHandler 추출

**Files:**
- Create: `lib/fediverse/inbox/follow_handler.rb`
- Create: `spec/lib/fediverse/inbox/follow_handler_spec.rb`
- Modify: `lib/fediverse/inbox.rb` (follow 관련 메서드 삭제, `require` 추가, `register_handler` 변경)
- Modify: `spec/lib/fediverse/inbox_spec.rb` (follow 관련 describe 블록 이동)

- [ ] **Step 1: 새 spec 파일로 기존 follow 관련 테스트 이동 (실패 상태)**

`spec/lib/fediverse/inbox_spec.rb`에서 다음 `describe` 블록들을 `spec/lib/fediverse/inbox/follow_handler_spec.rb`로 통째로 옮기고, 원본에서는 제거한다:
- `describe '#handle_create_follow_request'`
- `describe '.dispatch_request for inbound Follow with eager acceptance'`
- `describe '.dispatch_followed_callback compatibility'`
- `describe '#handle_accept_follow_request'`
- `describe '#handle_undo_follow_request'`
- `describe '#handle_reject_follow_request'`

새 spec 파일 상단 구조:

```ruby
require 'rails_helper'
require 'fediverse/inbox'
require 'fediverse/inbox/follow_handler'
require 'fediverse/request'

module Fediverse
  class Inbox
    RSpec.describe FollowHandler do
      let(:local_actor) { FactoryBot.create(:user).federails_actor }
      let(:distant_actor) { FactoryBot.create :distant_actor }

      # 이동된 describe 블록들
    end
  end
end
```

기존 spec에서 `described_class.send(:handle_create_follow_request, ...)` → `Fediverse::Inbox::FollowHandler.handle_create_follow_request(...)`으로 교체 (`send`와 private 호출 제거 — 이동 후 모듈의 public class method가 된다).

`.dispatch_request for inbound Follow with eager acceptance`는 상위 레벨 디스패치 테스트이지만 follow 콜백 경로를 다루므로 follow_handler_spec에 유지하되 내부에서 `Fediverse::Inbox.dispatch_request(payload)`를 호출하는 형태는 그대로 둔다 (엔드-투-엔드 검증).

- [ ] **Step 2: 테스트 실행해서 실패 확인**

Run: `bundle exec rspec spec/lib/fediverse/inbox/follow_handler_spec.rb`
Expected: FAIL — `NameError: uninitialized constant Fediverse::Inbox::FollowHandler` (혹은 `require 'fediverse/inbox/follow_handler'` 로드 실패)

- [ ] **Step 3: FollowHandler 모듈 생성**

파일 생성: `lib/fediverse/inbox/follow_handler.rb`

```ruby
# rbs_inline: enabled

require 'fediverse/request'

module Fediverse
  class Inbox
    module FollowHandler
      class << self
        # Creates a Following record from an incoming Follow activity.
        #: (Hash[String, untyped]) -> Federails::Following
        def handle_create_follow_request(activity)
          actor        = Federails::Actor.find_or_create_by_object activity['actor']
          target_actor = Federails::Actor.find_or_create_by_object activity['object']

          follow_activity = inbound_follow_activity(actor: actor, target_actor: target_actor, activity: activity)
          following = Federails::Following.find_or_initialize_by actor: actor, target_actor: target_actor
          if following.new_record?
            following.federated_url = activity['id']
            following.save!
            dispatch_followed_callback(target_actor, following, follow_activity)
          else
            following.update!(federated_url: activity['id']) if following.federated_url.blank? && activity['id'].present?
            resend_accept_for_duplicate_follow(following, follow_activity) if following.accepted?
          end

          following
        end

        # Marks a pending Following as accepted when the target actor confirms.
        #: (Hash[String, untyped]) -> Federails::Activity?
        def handle_accept_follow_request(activity)
          original_activity = Request.dereference(activity['object'])

          actor        = Federails::Actor.find_or_create_by_object original_activity['actor']
          target_actor = Federails::Actor.find_or_create_by_object original_activity['object']
          raise 'Follow not accepted by target actor but by someone else' if activity['actor'] != target_actor.federated_url

          follow = Federails::Following.find_by actor: actor, target_actor: target_actor
          unless follow
            Federails.logger.warn do
              "Follow not found for #{actor.federated_url} -> #{target_actor.federated_url}. " \
                "Original activity id: #{activity['object']}"
            end
            return
          end

          follow_activity = follow.follow_activity
          unless follow_activity
            Federails.logger.warn do
              "Follow activity not found for #{actor.federated_url} -> #{target_actor.federated_url}. " \
                "Original activity id: #{activity['object']}"
            end
            return
          end
          follow.accept!(follow_activity: follow_activity)
        end

        # Destroys a Following record when the follower undoes their Follow.
        #: (Hash[String, untyped]) -> Federails::Following?
        def handle_undo_follow_request(activity)
          original_activity = activity['object']

          actor        = Federails::Actor.find_or_create_by_object original_activity['actor']
          target_actor = Federails::Actor.find_or_create_by_object original_activity['object']

          follow = Federails::Following.find_by actor: actor, target_actor: target_actor
          follow&.destroy
        end

        # Destroys a pending Following when the target actor rejects the request.
        # AP Section 7.7: MUST NOT add to Following collection on Reject.
        #: (Hash[String, untyped]) -> Federails::Following?
        def handle_reject_follow_request(activity)
          original_activity = Request.dereference(activity['object'])

          actor = Federails::Actor.find_or_create_by_object(original_activity['actor'])
          target_actor = Federails::Actor.find_or_create_by_object(original_activity['object'])
          raise 'Follow not rejected by target actor but by someone else' if activity['actor'] != target_actor.federated_url

          follow = Federails::Following.pending.find_by(actor: actor, target_actor: target_actor)
          follow&.destroy
        end

        private

        # Re-sends an Accept Activity when a Follow is received for an already-accepted Following
        # under a new activity id. De-duplication in dispatch_request ensures this path is only
        # reached for genuinely new inbound Follow activities.
        #: (Federails::Following, Federails::Activity?) -> void
        def resend_accept_for_duplicate_follow(following, follow_activity)
          return unless follow_activity

          Federails::Activity.create!(
            actor:  following.target_actor,
            action: 'Accept',
            entity: follow_activity,
            to:     [following.actor.federated_url]
          )
        end

        #: (actor: Federails::Actor, target_actor: Federails::Actor, activity: Hash[String, untyped]) -> Federails::Activity?
        def inbound_follow_activity(actor:, target_actor:, activity:)
          return Federails::Activity.find_by(actor: actor, action: 'Follow', entity: target_actor) if actor.local?

          Federails::Activity.find_or_initialize_by(actor: actor, action: 'Follow', entity: target_actor).tap do |follow_activity|
            follow_activity.federated_url = activity['id'] if follow_activity.federated_url.blank? && activity['id'].present?
            follow_activity.to = activity['to'] || [target_actor.federated_url]
            follow_activity.cc = activity['cc']
            follow_activity.bto = activity['bto']
            follow_activity.bcc = activity['bcc']
            follow_activity.audience = activity['audience']
            follow_activity.save! if follow_activity.new_record? || follow_activity.changed?
          end
        end

        #: (Federails::Actor, Federails::Following, Federails::Activity?) -> void
        def dispatch_followed_callback(target_actor, following, follow_activity)
          return unless target_actor&.entity

          target_actor.entity.class.send(:dispatch_followed_callback, target_actor.entity, following, follow_activity: follow_activity)
        end
      end
    end
  end
end

Fediverse::Inbox.register_handler 'Follow', '*', Fediverse::Inbox::FollowHandler, :handle_create_follow_request
Fediverse::Inbox.register_handler 'Accept', 'Follow', Fediverse::Inbox::FollowHandler, :handle_accept_follow_request
Fediverse::Inbox.register_handler 'Reject', 'Follow', Fediverse::Inbox::FollowHandler, :handle_reject_follow_request
Fediverse::Inbox.register_handler 'Undo', 'Follow', Fediverse::Inbox::FollowHandler, :handle_undo_follow_request
```

- [ ] **Step 4: Inbox에서 follow 관련 코드 제거**

`lib/fediverse/inbox.rb`:
1. 상단에 `require 'fediverse/inbox/follow_handler'` 추가 (block_handler require 바로 밑)
2. `handle_create_follow_request`, `resend_accept_for_duplicate_follow`, `handle_accept_follow_request`, `handle_undo_follow_request`, `handle_reject_follow_request`, `inbound_follow_activity`, `dispatch_followed_callback` 메서드 전체 삭제
3. 파일 하단 `register_handler` 호출 변경:
   - `register_handler 'Follow', '*', self, :handle_create_follow_request` 삭제
   - `register_handler 'Accept', 'Follow', self, :handle_accept_follow_request` 삭제
   - `register_handler 'Reject', 'Follow', self, :handle_reject_follow_request` 삭제
   - `register_handler 'Undo', 'Follow', self, :handle_undo_follow_request` 삭제
   (이들은 `follow_handler.rb` 하단에서 호출됨)

- [ ] **Step 5: 테스트 실행**

Run: `bundle exec rspec spec/lib/fediverse/inbox/follow_handler_spec.rb spec/lib/fediverse/inbox_spec.rb`
Expected: PASS (양쪽 모두)

추가 회귀 확인:
Run: `bundle exec rspec spec/lib/fediverse/inbox/ spec/lib/fediverse/inbox_spec.rb spec/models/federails/following_spec.rb spec/requests/federation/`
Expected: PASS

- [ ] **Step 6: RBS 재생성**

Run: `rbs-inline --base=lib --output lib/fediverse/inbox.rb lib/fediverse/inbox/follow_handler.rb`
Expected: `sig/generated/fediverse/inbox.rbs` 및 `sig/generated/fediverse/inbox/follow_handler.rbs` 갱신.

변경 내용 검토:
Run: `git diff sig/`
Expected: `inbox.rbs`에서 follow 관련 private 메서드 시그니처 제거, `inbox/follow_handler.rbs` 신규 생성.

- [ ] **Step 7: 린트**

Run: `bundle exec rubocop lib/fediverse/inbox.rb lib/fediverse/inbox/follow_handler.rb spec/lib/fediverse/inbox_spec.rb spec/lib/fediverse/inbox/follow_handler_spec.rb`
Expected: no offenses (혹은 기존과 동일한 예외)

- [ ] **Step 8: 커밋**

```bash
git add lib/fediverse/inbox.rb lib/fediverse/inbox/follow_handler.rb \
        spec/lib/fediverse/inbox_spec.rb spec/lib/fediverse/inbox/follow_handler_spec.rb \
        sig/generated/fediverse/inbox.rbs sig/generated/fediverse/inbox/follow_handler.rbs
git commit -m "refactor: Follow 관련 inbox 핸들러를 FollowHandler 모듈로 분리"
```

---

## Task 2: DeleteHandler 추출

**Files:**
- Create: `lib/fediverse/inbox/delete_handler.rb`
- Create: `spec/lib/fediverse/inbox/delete_handler_spec.rb`
- Modify: `lib/fediverse/inbox.rb` (delete 관련 메서드 삭제, `require` 추가, 이른 분기·register 변경)
- Modify: `spec/lib/fediverse/inbox_spec.rb` (delete/undelete describe 블록 이동; `dispatch_request`의 Delete 관련 context는 dispatch_request describe에 유지)

- [ ] **Step 1: delete/undelete 테스트를 새 spec 파일로 이동 (실패 상태)**

`spec/lib/fediverse/inbox_spec.rb`에서 아래 블록을 `spec/lib/fediverse/inbox/delete_handler_spec.rb`로 이동:
- `describe '#handle_delete_request'`
- `describe '#handle_undelete_request'`

`describe '.dispatch_request'` 내부의 `'when a Delete activity has already been processed'` context는 dispatch_request 자체 행동(중복 감지) 검증이므로 `inbox_spec.rb`에 유지한다.

새 spec 파일 구조:

```ruby
require 'rails_helper'
require 'fediverse/inbox'
require 'fediverse/inbox/delete_handler'

module Fediverse
  class Inbox
    RSpec.describe DeleteHandler do
      let(:local_actor) { FactoryBot.create(:user).federails_actor }
      let(:distant_actor) { FactoryBot.create :distant_actor }

      # 이동된 describe 블록들
      # described_class.send(:handle_delete_request, payload) → described_class.handle_delete_request(payload)
    end
  end
end
```

- [ ] **Step 2: 테스트 실행해서 실패 확인**

Run: `bundle exec rspec spec/lib/fediverse/inbox/delete_handler_spec.rb`
Expected: FAIL — `NameError: uninitialized constant Fediverse::Inbox::DeleteHandler`

- [ ] **Step 3: DeleteHandler 모듈 생성**

파일 생성: `lib/fediverse/inbox/delete_handler.rb`

```ruby
# rbs_inline: enabled

require 'fediverse/request'

module Fediverse
  class Inbox
    module DeleteHandler
      class << self
        # Early-dispatch path invoked from Inbox.dispatch_request before dereferencing.
        # Handles the Delete case where the target object may already be gone remotely.
        #: (Hash[String, untyped]) -> untyped
        def dispatch_delete_request(payload)
          payload['object'] = payload['object']['id'] unless payload['object'].is_a? String
          object = Federails::Utils::Object.find_distant_object_in_all payload['object']
          return if object.blank?

          object.run_callbacks :on_federails_delete_requested
        end

        # Triggers on_federails_delete_requested callback on the matching local object.
        #: (Hash[String, untyped]) -> void
        def handle_delete_request(activity)
          object = Federails::Utils::Object.find_distant_object_in_all(activity['object'])
          return if object.blank?

          object.run_callbacks :on_federails_delete_requested
        end

        # Triggers on_federails_undelete_requested callback when an Undo+Delete is received.
        #: (Hash[String, untyped]) -> void
        def handle_undelete_request(activity)
          delete_activity = Request.dereference(activity['object'])
          object = Federails::Utils::Object.find_distant_object_in_all(delete_activity['object'])
          return if object.blank?

          object.run_callbacks :on_federails_undelete_requested
        end
      end
    end
  end
end

Fediverse::Inbox.register_handler 'Delete', '*', Fediverse::Inbox::DeleteHandler, :handle_delete_request
Fediverse::Inbox.register_handler 'Undo', 'Delete', Fediverse::Inbox::DeleteHandler, :handle_undelete_request
```

- [ ] **Step 4: Inbox에서 delete 관련 코드 제거 및 위임**

`lib/fediverse/inbox.rb`:
1. 상단 `require 'fediverse/inbox/follow_handler'` 다음에 `require 'fediverse/inbox/delete_handler'` 추가
2. `dispatch_request` 내부:
   ```ruby
   if payload['type'] == 'Delete'
     result = dispatch_delete_request(payload)
     record_processed_activity(payload, dispatched_at) if result
     return result
   end
   ```
   →
   ```ruby
   if payload['type'] == 'Delete'
     result = DeleteHandler.dispatch_delete_request(payload)
     record_processed_activity(payload, dispatched_at) if result
     return result
   end
   ```
3. `dispatch_delete_request`, `handle_delete_request`, `handle_undelete_request` 메서드 전체 삭제
4. 파일 하단 register_handler 호출 제거:
   - `register_handler 'Delete', '*', self, :handle_delete_request`
   - `register_handler 'Undo', 'Delete', self, :handle_undelete_request`

- [ ] **Step 5: 테스트 실행**

Run: `bundle exec rspec spec/lib/fediverse/inbox/delete_handler_spec.rb spec/lib/fediverse/inbox_spec.rb`
Expected: PASS

추가 회귀:
Run: `bundle exec rspec spec/lib/fediverse/ spec/requests/federation/`
Expected: PASS

- [ ] **Step 6: RBS 재생성**

Run: `rbs-inline --base=lib --output lib/fediverse/inbox.rb lib/fediverse/inbox/delete_handler.rb`
Expected: `inbox.rbs`에서 delete 관련 시그니처 제거, `inbox/delete_handler.rbs` 신규.

- [ ] **Step 7: 린트**

Run: `bundle exec rubocop lib/fediverse/inbox.rb lib/fediverse/inbox/delete_handler.rb spec/lib/fediverse/inbox_spec.rb spec/lib/fediverse/inbox/delete_handler_spec.rb`
Expected: no offenses.

- [ ] **Step 8: 커밋**

```bash
git add lib/fediverse/inbox.rb lib/fediverse/inbox/delete_handler.rb \
        spec/lib/fediverse/inbox_spec.rb spec/lib/fediverse/inbox/delete_handler_spec.rb \
        sig/generated/fediverse/inbox.rbs sig/generated/fediverse/inbox/delete_handler.rbs
git commit -m "refactor: Delete 관련 inbox 핸들러를 DeleteHandler 모듈로 분리"
```

---

## Task 3: 문서 및 CHANGELOG 업데이트

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: CHANGELOG.md 최상단 `## [Unreleased]` (없으면 생성)에 항목 추가**

```markdown
## [Unreleased]

### Changed
- `Fediverse::Inbox` 내 Follow/Accept/Reject/Undo-Follow 핸들러를 `Fediverse::Inbox::FollowHandler`로,
  Delete/Undo-Delete 핸들러를 `Fediverse::Inbox::DeleteHandler`로 분리. 외부 API(레지스트리 기반 dispatch)는 변함없음.
```

- [ ] **Step 2: docs/usage.md 검토**

Run: `grep -n "Inbox\|handle_" docs/usage.md`
Expected: follow/delete handler를 직접 참조하는 라인이 없거나, 있다면 모듈 경로 갱신.

실제 참조가 있으면 해당 라인을 신규 모듈 경로로 업데이트. 없으면 그대로 둔다.

- [ ] **Step 3: README 점검**

Run: `grep -n "handle_create_follow_request\|Inbox::" README.md`
Expected: 사용자용 호출 예가 없음. 있을 경우 경로 업데이트.

- [ ] **Step 4: 전체 테스트 스윕**

Run: `bundle exec rspec`
Expected: 모든 예제 통과.

- [ ] **Step 5: steep 타입체크 (설정되어 있다면)**

Run: `bundle exec steep check 2>&1 | tail -20`
Expected: 신규 에러 없음. 사전 대비 동일한 결과.

*Steep이 프로젝트에 없다면 이 단계는 생략.*

- [ ] **Step 6: 커밋**

```bash
git add CHANGELOG.md docs/usage.md README.md
git commit -m "docs: inbox 핸들러 분리 관련 변경사항 기록"
```

(docs/usage.md, README.md에 변경이 없으면 생략하고 `git add CHANGELOG.md`만)

---

## Task 4: PR 준비

- [ ] **Step 1: 로컬 브랜치 확인 및 원격 푸시**

Run: `git status && git log origin/main..HEAD --oneline`
Expected: 3개 커밋(Task 1, 2, 3). 작업 트리 clean.

Run: `git push -u origin refactor/inbox-follow-delete-handlers`
Expected: 브랜치 업로드 성공.

- [ ] **Step 2: PR 생성**

```bash
gh pr create --title "refactor: inbox 핸들러를 FollowHandler/DeleteHandler로 분리" --body "$(cat <<'EOF'
## Summary
- `lib/fediverse/inbox.rb`의 Follow/Accept/Reject/Undo-Follow 핸들러를 `Fediverse::Inbox::FollowHandler`로 분리
- Delete/Undo-Delete 핸들러와 이른 분기 로직을 `Fediverse::Inbox::DeleteHandler`로 분리
- 기존 `LikeHandler`/`AnnounceHandler`/`BlockHandler` 컨벤션에 맞춰 각 핸들러 파일 하단에서 `register_handler` 호출
- 행동 변경 없음, 순수 구조 리팩터링

## Test plan
- [ ] `bundle exec rspec spec/lib/fediverse/inbox_spec.rb spec/lib/fediverse/inbox/` 전체 통과
- [ ] `bundle exec rspec spec/requests/federation/` 통과 (end-to-end Follow/Delete 흐름)
- [ ] `bundle exec rubocop` 신규 경고 없음
- [ ] RBS 시그니처 자동 생성 결과 반영 확인
EOF
)"
```

- [ ] **Step 3: PR URL 보고**

PR URL을 사용자에게 공유.

---

## Self-Review Checklist

- **Spec coverage**: 이동 대상 메서드 6종(handle_create/accept/reject/undo-follow, handle_delete, handle_undelete) + 이른 분기(dispatch_delete_request) + Follow 헬퍼 3종(resend_accept_for_duplicate_follow, inbound_follow_activity, dispatch_followed_callback) 모두 Task 1 또는 Task 2의 코드 블록에서 실제 구현과 함께 배치됨. ✓
- **Placeholder scan**: 구체 코드/명령 없이 "적절히 처리" 수준의 스텝 없음. ✓
- **Type consistency**: 메서드명·모듈명 모든 Task에서 동일(`FollowHandler`, `DeleteHandler`, `handle_create_follow_request` 등). register 시 전달 symbol도 일치. ✓
- **행동 불변**: private → public class method 변경은 Inbox 내부 `register_handler`가 `klass.send method, payload`로 호출하므로 가시성 영향 없음 ([inbox.rb:66](../../lib/fediverse/inbox.rb:66)). ✓
