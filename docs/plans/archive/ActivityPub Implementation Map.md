# ActivityPub 스펙 ↔ Federails 구현 맵 (운영용)

목표: ActivityPub RFC(https://www.w3.org/TR/activitypub/) 요구사항을 **Federails 코드/테스트/이슈**에 연결해서,
"구현됨/부분/미구현"을 빠르게 판정할 수 있게 한다.

관련 노트:
- [[Status 2026-03-03]]
- [[ActivityPub RFC Compliance]] (MUST/MUST NOT 체크리스트 + Evidence)

---

## 상태 기준(권장)
- ✅ Implemented: 동작이 코드+테스트(또는 상호운용 확인)로 뒷받침됨
- 🟡 Partial: 일부 케이스/경로만 구현, 혹은 테스트 부재
- ❌ Not implemented: 코드 경로 없음/명시적으로 미지원
- ⚪ Unknown: 아직 확인 안 함 (Evidence가 비어있음)

## Evidence 작성 가이드
각 RFC 항목마다 아래 중 1개 이상을 붙이는 걸 원칙으로:
1) **코드 위치**: GitLab 파일 링크 + 라인
2) **테스트**: spec 파일/통합 테스트 링크 + 어떤 시나리오를 커버하는지
3) **이슈/MR**: 관련 작업이 진행 중임을 보여주는 링크
4) (가능하면) **상호운용 결과**: Mastodon/PeerTube 등과 실제 연동 확인 메모

---

## 우선순위(추천)
### P0: 연합 동작의 뼈대(서버-서버)
- Actor 문서: inbox/outbox, (선택) followers/following
- Inbox POST 수신 + 처리
- Outbox publish → delivery
- Delivery 비동기/재시도/중복제거(스펙 MUST)

### P1: Discovery
- WebFinger
- NodeInfo

### P2: 주소지정(Addressing) / 전달 확장
- to/cc/bto/bcc/audience
- sharedInbox 최적화

### P3: 스펙 엣지/보안/성능
- multi-type activities(array type)
- 수신 객체 검증/스푸핑 방지(가능한 범위)
- key at-rest 암호화 등

---

## Federails 오픈 이슈(스펙 관련) 빠른 링크
- #24 Handle multi-type activities: https://gitlab.com/experimentslabs/federails/-/issues/24
- #31 Fan-out inbox delivery jobs: https://gitlab.com/experimentslabs/federails/-/issues/31
- #28 to/cc addressing: https://gitlab.com/experimentslabs/federails/-/issues/28
- #29 bcc/bto/audience: https://gitlab.com/experimentslabs/federails/-/issues/29
- #26 Encrypt private keys at rest: https://gitlab.com/experimentslabs/federails/-/issues/26
- #23 sensible User-Agent: https://gitlab.com/experimentslabs/federails/-/issues/23

---

## 다음 액션(체크리스트)
- [ ] [[ActivityPub RFC Compliance]]에서 MUST 항목 10개 선정
- [ ] 각 항목에 Evidence(코드/테스트/이슈) 채우기
- [ ] 상태를 ✅/🟡/❌로 업데이트
- [ ] Unknown이 오래 남는 항목은 이슈로 쪼개서 추적
