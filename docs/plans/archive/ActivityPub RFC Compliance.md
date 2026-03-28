# ActivityPub RFC 컴플라이언스 매트릭스 (Federails)

- 스펙: https://www.w3.org/TR/activitypub/
- Federails 자동 리포트(원본): https://gitlab.com/experimentslabs/federails/-/blob/main/report.md
- 목표: MUST/MUST NOT 우선으로 **구현됨/부분/미구현/불명(unknown)** 을 구분하고, 근거(코드/테스트/이슈)를 링크

## 상태 정의(권장)
- ✅ Implemented
- 🟡 Partial
- ❌ Not implemented
- ⚪ Unknown (아직 근거를 못 찾음)

## 업데이트 규칙(추천)
1) 해당 RFC 항목이 실제로 구현되었는지 확인할 **근거**를 적는다:
   - 관련 컨트롤러/모델/서비스 파일 링크(라인 포함)
   - 스펙 테스트/통합테스트 링크
   - 관련 이슈/머지리퀘스트
2) 근거가 없으면 상태는 ⚪ Unknown으로 둔다.

## MUST / MUST NOT 체크리스트(초기값=Unknown)

## MUST 항목 10개 (초기 판정)

### 1. 4.1 Actor objects MUST have inbox/outbox
- Status: 🟡 Partial
- Note: Actor 문서에 inbox/outbox 필드를 제공하나, inbox 자체를 OrderedCollection으로 GET 제공하는지(5.2)는 별도 확인 필요.
- Evidence:
  - Actor JSON includes inbox/outbox: https://gitlab.com/experimentslabs/federails/-/blob/main/app/views/federails/server/actors/_actor.activitypub.jbuilder (lines ~15-16)
  - Inbox endpoint exists (POST /actors/:id/inbox): https://gitlab.com/experimentslabs/federails/-/blob/main/app/controllers/federails/server/activities_controller.rb (create action)
  - Outbox endpoint exists (GET /actors/:id/outbox.json): https://gitlab.com/experimentslabs/federails/-/blob/main/app/controllers/federails/server/activities_controller.rb (outbox action)
  - Outbox renders OrderedCollectionPage: https://gitlab.com/experimentslabs/federails/-/blob/main/app/views/federails/server/activities/outbox.activitypub.jbuilder

### 2. 5.1 Outbox MUST be an OrderedCollection
- Status: 🟡 Partial
- Note: 현재는 OrderedCollection(컨테이너) + page 분리 대신, page 형태로 제공. 스펙 의도에 부합하는지/호환성 확인 필요.
- Evidence:
  - Outbox response type OrderedCollectionPage: https://gitlab.com/experimentslabs/federails/-/blob/main/app/views/federails/server/activities/outbox.activitypub.jbuilder

### 3. 7 MUST: POST Content-Type and GET Accept application/ld+json profile=AS
- Status: ✅ Implemented
- Note: 수신(서버) 측에서 Content-Type 강제검증은 아직 확인 필요.
- Evidence:
  - Delivery request sets Content-Type/Accept to activitypub mime: https://gitlab.com/experimentslabs/federails/-/blob/main/lib/fediverse/notifier.rb (request method sets headers)

### 4. 7 MUST: delivery activities MUST provide object (Create/Update/Delete/Follow/Add/Remove/Like/Block/Undo)
- Status: 🟡 Partial
- Note: entity가 nil/미지원 타입일 때 object 누락 가능성. 또한 addressing(bto/bcc/audience)은 아직 미구현(#29).
- Evidence:
  - Activity payload includes actor+type and sets object from entity: https://gitlab.com/experimentslabs/federails/-/blob/main/app/views/federails/server/activities/_activity.activitypub.jbuilder

### 5. 5.3/5.4 followers/following collections MUST be Collection or OrderedCollection
- Status: ✅ Implemented
- Evidence:
  - followers returns OrderedCollectionPage: https://gitlab.com/experimentslabs/federails/-/blob/main/app/views/federails/server/actors/followers.activitypub.jbuilder
  - following returns OrderedCollectionPage: https://gitlab.com/experimentslabs/federails/-/blob/main/app/views/federails/server/actors/following.activitypub.jbuilder
  - Actor JSON links followers/following: https://gitlab.com/experimentslabs/federails/-/blob/main/app/views/federails/server/actors/_actor.activitypub.jbuilder (lines ~17-18)

### 6. 5.6 MUST NOT deliver to Public special collection
- Status: ✅ Implemented
- Evidence:
  - Notifier excludes Public from recipients: https://gitlab.com/experimentslabs/federails/-/blob/main/lib/fediverse/notifier.rb (reject Public constant)
  - Default addressing sets to=Public, cc includes followers: https://gitlab.com/experimentslabs/federails/-/blob/main/app/models/federails/activity.rb (set_default_addressing)

### 7. 7.1 MUST de-duplicate final recipient list
- Status: ✅ Implemented
- Note: RFC 요구사항. 구현 시 uniq + canonicalization 필요.
- Evidence:
  - inboxes_for builds list but does not uniq: https://gitlab.com/experimentslabs/federails/-/blob/main/lib/fediverse/notifier.rb

### 8. 7.1 MUST exclude delivering actor from recipients
- Status: ✅ Implemented
- Note: actor가 자기 자신 주소를 to/cc에 넣을 경우(실수/악성) 방지 필요.
- Evidence:
  - Added self-exclusion: `inboxes.reject { |url| url == activity.actor.inbox_url }`: https://gitlab.com/experimentslabs/federails/-/blob/main/lib/fediverse/notifier.rb (inboxes_for)

### 9. 5.2 MUST de-duplicate activities returned by inbox (by activity id)
- Status: ⚪ Unknown
- Note: 현재 코드에서 inbox 조회 엔드포인트가 있는지부터 확인 필요.
- Evidence:
  - Inbox GET(컬렉션 조회) 구현 파일을 아직 못 찾음. 현재 확인된 것은 inbox POST(create)만.

### 10. 7.1.1 MUST target to/bto/cc/bcc/audience when delivering from outbox
- Status: 🟡 Partial
- Note: bto/bcc/audience 미지원 → #29. 따라서 MUST 완전 충족은 아님.
- Evidence:
  - Notifier considers to+cc only: https://gitlab.com/experimentslabs/federails/-/blob/main/lib/fediverse/notifier.rb (uses [activity.to, activity.cc])


### Section 3.1 (https://www.w3.org/TR/activitypub/#obj-id)
- ⚪ **MUST** `objects__objects_identifiers__unique` — All Objects in [ActivityStreams] should have unique global identifiers. ActivityPub extends this requirement; all objects distributed by the ActivityPub protocol MUST have unique global identifiers, unless they are intentionally transient (short lived activities that are not intended to be able to be looked up, such as some kinds of chat messages or game notifications). These identifiers must fall into one of the following groups: 1. Publicly dereferencable URIs, such as HTTPS URIs, with their authority belonging to that of their originating server. (Publicly facing content SHOULD use HTTPS URIs). 2. An ID explicitly specified as the JSON null object, which implies an anonymous object (a part of its parent context)
  - Status: ⚪ Unknown
  - Evidence: 
- ⚪ **MUST** `objects__objects_identifiers__provided_for_activities` — Identifiers MUST be provided for activities posted in server to server communication, unless the activity is intentionally transient. However, for client to server communication, a server receiving an object posted to the outbox with no specified id SHOULD allocate an object ID in the actor's namespace and attach it to the posted object.
  - Status: ⚪ Unknown
  - Evidence: 

### Section 3.2 (https://www.w3.org/TR/activitypub/#retrieving-objects)
- ⚪ **MUST** `objects__retrieving_objects__present_object_representation` — The HTTP GET method may be dereferenced against an object's id property to retrieve the activity. Servers MAY use HTTP content negotiation as defined in [RFC7231] to select the type of data to return in response to a request, but MUST present the ActivityStreams object representation in response to application/ld+json; profile="https://www.w3.org/ns/activitystreams", and SHOULD also present the ActivityStreams representation in response to application/activity+json as well. The client MUST specify an Accept header with the application/ld+json; profile="https://www.w3.org/ns/activitystreams" media type in order to retrieve the activity.
  - Status: ⚪ Unknown
  - Evidence: 
- ⚪ **MUST** `(no-id)` — The HTTP GET method may be dereferenced against an object's id property to retrieve the activity. Servers MAY use HTTP content negotiation as defined in [RFC7231] to select the type of data to return in response to a request, but MUST present the ActivityStreams object representation in response to application/ld+json; profile="https://www.w3.org/ns/activitystreams", and SHOULD also present the ActivityStreams representation in response to application/activity+json as well. The client MUST specify an Accept header with the application/ld+json; profile="https://www.w3.org/ns/activitystreams" media type in order to retrieve the activity.
  - Status: ⚪ Unknown
  - Evidence: 

### Section 4.1 (https://www.w3.org/TR/activitypub/#actor-objects)
- ⚪ **MUST** `(no-id)` — Actor objects MUST have, in addition to the properties mandated by 3.1 Object Identifiers, the following properties: inbox A reference to an [ActivityStreams] OrderedCollection comprised of all the messages received by the actor; see 5.2 Inbox. outbox An [ActivityStreams] OrderedCollection comprised of all the messages produced by the actor; see 5.1 Outbox.
  - Status: ⚪ Unknown
  - Evidence: 
- ⚪ **MUST NOT** `(no-id)` — sharedInbox An optional endpoint used for wide delivery of publicly addressed activities and activities sent to followers. sharedInbox endpoints SHOULD also be publicly readable OrderedCollection objects containing objects addressed to the Public special collection. Reading from the sharedInbox endpoint MUST NOT present objects which are not addressed to the Public endpoint.
  - Status: ⚪ Unknown
  - Evidence: 

### Section 5 (https://www.w3.org/TR/activitypub/#collections)
- ⚪ **MUST** `(no-id)` — An OrderedCollection MUST be presented consistently in reverse chronological order
  - Status: ⚪ Unknown
  - Evidence: 

### Section 5.1 (https://www.w3.org/TR/activitypub/#outbox)
- ⚪ **MUST** `(no-id)` — The outbox is discovered through the outbox property of an actor's profile. The outbox MUST be an OrderedCollection.
  - Status: ⚪ Unknown
  - Evidence: 

### Section 5.2 (https://www.w3.org/TR/activitypub/#inbox)
- ⚪ **MUST** `(no-id)` — The inbox is discovered through the inbox property of an actor's profile. The inbox MUST be an OrderedCollection.
  - Status: ⚪ Unknown
  - Evidence: 
- ⚪ **MUST** `(no-id)` — The server MUST perform de-duplication of activities returned by the inbox. Duplication can occur if an activity is addressed both to an actor's followers, and a specific actor who also follows the recipient actor, and the server has failed to de-duplicate the recipients list. Such deduplication MUST be performed by comparing the id of the activities and dropping any activities already seen.
  - Status: ⚪ Unknown
  - Evidence: 
- ⚪ **MUST** `(no-id)` — The server MUST perform de-duplication of activities returned by the inbox. Duplication can occur if an activity is addressed both to an actor's followers, and a specific actor who also follows the recipient actor, and the server has failed to de-duplicate the recipients list. Such deduplication MUST be performed by comparing the id of the activities and dropping any activities already seen.
  - Status: ⚪ Unknown
  - Evidence: 

### Section 5.3 (https://www.w3.org/TR/activitypub/#followers)
- ⚪ **MUST** `(no-id)` — Every actor SHOULD have a followers collection. This is a list of everyone who has sent a Follow activity for the actor, added as a side effect. This is where one would find a list of all the actors that are following the actor. The followers collection MUST be either an OrderedCollection or a Collection and MAY be filtered on privileges of an authenticated user or as appropriate when no authentication is given.
  - Status: ⚪ Unknown
  - Evidence: 

### Section 5.4 (https://www.w3.org/TR/activitypub/#following)
- ⚪ **MUST** `(no-id)` — Every actor SHOULD have a following collection. This is a list of everybody that the actor has followed, added as a side effect. The following collection MUST be either an OrderedCollection or a Collection and MAY be filtered on privileges of an authenticated user or as appropriate when no authentication is given.
  - Status: ⚪ Unknown
  - Evidence: 

### Section 5.5 (https://www.w3.org/TR/activitypub/#liked)
- ⚪ **MUST** `(no-id)` — Every actor MAY have a liked collection. This is a list of every object from all of the actor's Like activities, added as a side effect. The liked collection MUST be either an OrderedCollection or a Collection and MAY be filtered on privileges of an authenticated user or as appropriate when no authentication is given.
  - Status: ⚪ Unknown
  - Evidence: 

### Section 5.6 (https://www.w3.org/TR/activitypub/#public-addressing)
- ⚪ **MUST NOT** `(no-id)` — Implementations MUST NOT deliver to the "public" special collection; it is not capable of receiving actual activities. However, actors MAY have a sharedInbox endpoint which is available for efficient shared delivery of public posts (as well as posts to followers-only); see 7.1.3 Shared Inbox Delivery.
  - Status: ⚪ Unknown
  - Evidence: 

### Section 5.7 (https://www.w3.org/TR/activitypub/#likes)
- ⚪ **MUST** `(no-id)` — Every object MAY have a likes collection. This is a list of all Like activities with this object as the object property, added as a side effect. The likes collection MUST be either an OrderedCollection or a Collection and MAY be filtered on privileges of an authenticated user or as appropriate when no authentication is given.
  - Status: ⚪ Unknown
  - Evidence: 

### Section 5.8 (https://www.w3.org/TR/activitypub/#shares)
- ⚪ **MUST** `(no-id)` — Every object MAY have a shares collection. This is a list of all Announce activities with this object as the object property, added as a side effect. The shares collection MUST be either an OrderedCollection or a Collection and MAY be filtered on privileges of an authenticated user or as appropriate when no authentication is given.
  - Status: ⚪ Unknown
  - Evidence: 

### Section 7 (https://www.w3.org/TR/activitypub/#server-to-server-interactions)
- ⚪ **MUST** `(no-id)` — POST requests (eg. to the inbox) MUST be made with a Content-Type of application/ld+json; profile="https://www.w3.org/ns/activitystreams" and GET requests (see also 3.2 Retrieving objects) with an Accept header of application/ld+json; profile="https://www.w3.org/ns/activitystreams".
  - Status: ⚪ Unknown
  - Evidence: 
- ⚪ **MUST** `(no-id)` — Servers performing delivery to the inbox or sharedInbox properties of actors on other servers MUST provide the object property in the activity: Create, Update, Delete, Follow, Add, Remove, Like, Block, Undo. Additionally, servers performing server to server delivery of the following activities MUST also provide the target property: Add, Remove.
  - Status: ⚪ Unknown
  - Evidence: 
- ⚪ **MUST** `(no-id)` — Servers performing delivery to the inbox or sharedInbox properties of actors on other servers MUST provide the object property in the activity: Create, Update, Delete, Follow, Add, Remove, Like, Block, Undo. Additionally, servers performing server to server delivery of the following activities MUST also provide the target property: Add, Remove.
  - Status: ⚪ Unknown
  - Evidence: 

### Section 7.1 (https://www.w3.org/TR/activitypub/#delivery)
- ⚪ **MUST** `(no-id)` — If a recipient is a Collection or OrderedCollection, then the server MUST dereference the collection (with the user's credentials) and discover inboxes for each item in the collection.
  - Status: ⚪ Unknown
  - Evidence: 
- ⚪ **MUST** `(no-id)` — Servers MUST limit the number of layers of indirections through collections which will be performed, which MAY be one.
  - Status: ⚪ Unknown
  - Evidence: 
- ⚪ **MUST** `(no-id)` — Servers MUST de-duplicate the final recipient list.
  - Status: ⚪ Unknown
  - Evidence: 
- ⚪ **MUST** `(no-id)` — Servers MUST also exclude actors from the list which are the same as the actor of the Activity being notified about. That is, actors shouldn't have their own activities delivered to themselves.
  - Status: ⚪ Unknown
  - Evidence: 

### Section 7.1.1 (https://www.w3.org/TR/activitypub/#outbox-delivery)
- ⚪ **MUST** `(no-id)` — When objects are received in the outbox (for servers which support both Client to Server interactions and Server to Server Interactions), the server MUST target and deliver to: The to, bto, cc, bcc or audience fields if their values are individuals or Collections owned by the actor.
  - Status: ⚪ Unknown
  - Evidence: 

### Section 7.1.2 (https://www.w3.org/TR/activitypub/#inbox-forwarding)
- ⚪ **MUST** `(no-id)` — When Activities are received in the inbox, the server needs to forward these to recipients that the origin was unable to deliver them to. To do this, the server MUST target and deliver to the values of to, cc, and/or audience if and only if all of the following are true: This is the first time the server has seen this Activity. The values of to, cc, and/or audience contain a Collection owned by the server. The values of inReplyTo, object, target and/or tag are objects owned by the server. The server SHOULD recurse through these values to look for linked objects owned by the server, and SHOULD set a maximum limit for recursion (ie. the point at which the thread is so deep the recipients followers may not mind if they are no longer getting updates that don't directly involve the recipient). The server MUST only target the values of to, cc, and/or audience on the original object being forwarded, and not pick up any new addressees whilst recursing through the linked objects (in case these addressees were purposefully amended by or via the client). The server MAY filter its delivery targets according to implementation-specific rules (for example, spam filtering).
  - Status: ⚪ Unknown
  - Evidence: 
- ⚪ **MUST** `(no-id)` — When Activities are received in the inbox, the server needs to forward these to recipients that the origin was unable to deliver them to. To do this, the server MUST target and deliver to the values of to, cc, and/or audience if and only if all of the following are true: This is the first time the server has seen this Activity. The values of to, cc, and/or audience contain a Collection owned by the server. The values of inReplyTo, object, target and/or tag are objects owned by the server. The server SHOULD recurse through these values to look for linked objects owned by the server, and SHOULD set a maximum limit for recursion (ie. the point at which the thread is so deep the recipients followers may not mind if they are no longer getting updates that don't directly involve the recipient). The server MUST only target the values of to, cc, and/or audience on the original object being forwarded, and not pick up any new addressees whilst recursing through the linked objects (in case these addressees were purposefully amended by or via the client). The server MAY filter its delivery targets according to implementation-specific rules (for example, spam filtering).
  - Status: ⚪ Unknown
  - Evidence: 

### Section 7.1.3 (https://www.w3.org/TR/activitypub/#shared-inbox-delivery)
- ⚪ **MUST** `(no-id)` — Origin servers sending publicly addressed activities to sharedInbox endpoints MUST still deliver to actors and collections otherwise addressed (through to, bto, cc, bcc, and audience) which do not have a sharedInbox and would not otherwise receive the activity through the sharedInbox mechanism.
  - Status: ⚪ Unknown
  - Evidence: 

### Section 7.3 (https://www.w3.org/TR/activitypub/#update-activity-inbox)
- ⚪ **MUST** `(no-id)` — The receiving server MUST take care to be sure that the Update is authorized to modify its object. At minimum, this may be done by ensuring that the Update and its object are of same origin.
  - Status: ⚪ Unknown
  - Evidence: 

### Section 7.5 (https://www.w3.org/TR/activitypub/#follow-activity-inbox)
- ⚪ **MUST NOT** `(no-id)` — In the case of a Reject, the server MUST NOT add the actor to the object actor''s Followers Collection.
  - Status: ⚪ Unknown
  - Evidence: 

### Section 7.7 (https://www.w3.org/TR/activitypub/#reject-activity-inbox)
- ⚪ **MUST NOT** `(no-id)` — If the object of a Reject received to an inbox is a Follow activity previously sent by the receiver, this means the recipient did not approve the Follow request. The server MUST NOT add the actor to the receiver's Following Collection.
  - Status: ⚪ Unknown
  - Evidence: 
