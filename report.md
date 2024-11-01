# Compliance status: ActivityPub RFC

Source specification: [https://www.w3.org/TR/activitypub/](https://www.w3.org/TR/activitypub/)

| status | id | section | verb | text |
|-------:|---:|---------|------|------|
| <span style='color: gray'>unknown</span> | [`objects__include_activitypub_context`](#objects__include_activitypub_context) | [3](https://www.w3.org/TR/activitypub/#obj) | should | ActivityPub defines some terms in addition to those provided by ActivityStreams. <br> These terms are provided in the ActivityPub JSON-LD context at https://www.w3.org/ns/activitystreams. <br> Implementers <mark>SHOULD</mark> include the ActivityPub context in their object definitions. <br> Implementers MAY include additional context as appropriate. <br>  |
| <span style='color: gray'>unknown</span> | [`objects__include_additional_context`](#objects__include_additional_context) | [3](https://www.w3.org/TR/activitypub/#obj) | may | ActivityPub defines some terms in addition to those provided by ActivityStreams. <br> These terms are provided in the ActivityPub JSON-LD context at https://www.w3.org/ns/activitystreams. <br> Implementers SHOULD include the ActivityPub context in their object definitions. <br> Implementers <mark>MAY</mark> include additional context as appropriate. <br>  |
| <span style='color: gray'>unknown</span> | [`objects__activitypub_share_activitystream_uri`](#objects__activitypub_share_activitystream_uri) | [3](https://www.w3.org/TR/activitypub/#obj) | note | ActivityPub shares the same URI / IRI conventions as in ActivityStreams. |
| <span style='color: gray'>unknown</span> | [`objects__validate_received_content`](#objects__validate_received_content) | [3](https://www.w3.org/TR/activitypub/#obj) | should | Servers <mark>SHOULD</mark> validate the content they receive to avoid content spoofing attacks. <br> (A server should do something at least as robust as checking that the object appears as received at its origin, but <br> mechanisms such as checking signatures would be better if available). No particular mechanism for verification is <br> authoritatively specified by this document, but please see Security Considerations for <br> some suggestions and good practices. <br>  |
| <span style='color: gray'>unknown</span> | [`objects__objects_identifiers__unique`](#objects__objects_identifiers__unique) | [3.1](https://www.w3.org/TR/activitypub/#obj-id) | must | All Objects in [ActivityStreams] should have unique global identifiers. ActivityPub extends this requirement; all <br> objects distributed by the ActivityPub protocol <mark>MUST</mark> have unique global identifiers, unless they are intentionally <br> transient (short lived activities that are not intended to be able to be looked up, such as some kinds of chat <br> messages or game notifications). These identifiers must fall into one of the following groups: <br>  <br>   1. Publicly dereferencable URIs, such as HTTPS URIs, with their authority belonging to that of their originating server. (Publicly facing content SHOULD use HTTPS URIs). <br>   2. An ID explicitly specified as the JSON null object, which implies an anonymous object (a part of its parent context) <br>  |
| <span style='color: gray'>unknown</span> | [`objects__objects_identifiers__use_https`](#objects__objects_identifiers__use_https) | [3.1](https://www.w3.org/TR/activitypub/#obj-id) | should | All Objects in [ActivityStreams] should have unique global identifiers. ActivityPub extends this requirement; all <br> objects distributed by the ActivityPub protocol MUST have unique global identifiers, unless they are intentionally <br> transient (short lived activities that are not intended to be able to be looked up, such as some kinds of chat <br> messages or game notifications). These identifiers must fall into one of the following groups: <br>  <br>   1. Publicly dereferencable URIs, such as HTTPS URIs, with their authority belonging to that of their originating server. (Publicly facing content <mark>SHOULD</mark> use HTTPS URIs). <br>   2. An ID explicitly specified as the JSON null object, which implies an anonymous object (a part of its parent context) <br>  |
| <span style='color: gray'>unknown</span> | [`objects__objects_identifiers__provided_for_activities`](#objects__objects_identifiers__provided_for_activities) | [3.1](https://www.w3.org/TR/activitypub/#obj-id) | must | Identifiers <mark>MUST</mark> be provided for activities posted in server to server communication, unless the activity is <br> intentionally transient. However, for client to server communication, a server receiving an object posted to the <br> outbox with no specified id SHOULD allocate an object ID in the actor's namespace and attach it to the posted object. <br>  |
| <span style='color: gray'>unknown</span> | [`objects__objects_identifiers__allocate_id`](#objects__objects_identifiers__allocate_id) | [3.1](https://www.w3.org/TR/activitypub/#obj-id) | should | Identifiers MUST be provided for activities posted in server to server communication, unless the activity is <br> intentionally transient. However, for client to server communication, a server receiving an object posted to the <br> outbox with no specified id <mark>SHOULD</mark> allocate an object ID in the actor's namespace and attach it to the posted object. <br>  |
| <span style='color: gray'>unknown</span> | [`objects__objects_identifiers__omit_id`](#objects__objects_identifiers__omit_id) | [3.1](https://www.w3.org/TR/activitypub/#obj-id) | may | All objects have the following properties: <br>  <br> id <br>   The object's unique global identifier (unless the object is transient, in which case the id <mark>MAY</mark> be omitted). <br> type <br>   The type of the object. <br>  |
| <span style='color: gray'>unknown</span> | [`objects__retrieving_objects__use_content_negociation`](#objects__retrieving_objects__use_content_negociation) | [3.2](https://www.w3.org/TR/activitypub/#retrieving-objects) | may | The HTTP GET method may be dereferenced against an object's id property to retrieve the activity. Servers <mark>MAY</mark> use HTTP <br> content negotiation as defined in [RFC7231] to select the type of data to return in response to a request, but MUST <br> present the ActivityStreams object representation in response to application/ld+json; <br> profile="https://www.w3.org/ns/activitystreams", and SHOULD also present the ActivityStreams representation in <br> response to application/activity+json as well. The client MUST specify an Accept header with the application/ld+json; <br> profile="https://www.w3.org/ns/activitystreams" media type in order to retrieve the activity. <br>  |
| <span style='color: gray'>unknown</span> | [`objects__retrieving_objects__present_object_representation`](#objects__retrieving_objects__present_object_representation) | [3.2](https://www.w3.org/TR/activitypub/#retrieving-objects) | must | The HTTP GET method may be dereferenced against an object's id property to retrieve the activity. Servers MAY use HTTP <br> content negotiation as defined in [RFC7231] to select the type of data to return in response to a request, but <mark>MUST</mark> <br> present the ActivityStreams object representation in response to application/ld+json; <br> profile="https://www.w3.org/ns/activitystreams", and SHOULD also present the ActivityStreams representation in <br> response to application/activity+json as well. The client MUST specify an Accept header with the application/ld+json; <br> profile="https://www.w3.org/ns/activitystreams" media type in order to retrieve the activity. <br>  |
| <span style='color: gray'>unknown</span> | [`objects__retrieving_objects__present_as_activity_json`](#objects__retrieving_objects__present_as_activity_json) | [3.2](https://www.w3.org/TR/activitypub/#retrieving-objects) | should | The HTTP GET method may be dereferenced against an object's id property to retrieve the activity. Servers MAY use HTTP <br> content negotiation as defined in [RFC7231] to select the type of data to return in response to a request, but MUST <br> present the ActivityStreams object representation in response to application/ld+json; <br> profile="https://www.w3.org/ns/activitystreams", and <mark>SHOULD</mark> also present the ActivityStreams representation in <br> response to application/activity+json as well. The client MUST specify an Accept header with the application/ld+json; <br> profile="https://www.w3.org/ns/activitystreams" media type in order to retrieve the activity. <br>  |
| <span style='color: gray'>unknown</span> |  | [3.2](https://www.w3.org/TR/activitypub/#retrieving-objects) | must | The HTTP GET method may be dereferenced against an object's id property to retrieve the activity. Servers MAY use HTTP <br> content negotiation as defined in [RFC7231] to select the type of data to return in response to a request, but MUST <br> present the ActivityStreams object representation in response to application/ld+json; <br> profile="https://www.w3.org/ns/activitystreams", and SHOULD also present the ActivityStreams representation in <br> response to application/activity+json as well. The client <mark>MUST</mark> specify an Accept header with the application/ld+json; <br> profile="https://www.w3.org/ns/activitystreams" media type in order to retrieve the activity. <br>  |
| <span style='color: gray'>unknown</span> |  | [3.2](https://www.w3.org/TR/activitypub/#retrieving-objects) | may | Servers <mark>MAY</mark> implement other behavior for requests which do not comply with the above requirement. (For example, <br> servers may implement additional legacy protocols, or may use the same URI for both HTML and ActivityStreams <br> representations of a resource). <br>  |
| <span style='color: gray'>unknown</span> |  | [3.2](https://www.w3.org/TR/activitypub/#retrieving-objects) | may | Servers <mark>MAY</mark> require authorization as specified in B.1 Authentication and Authorization, and may additionally implement <br> their own authorization rules. Servers SHOULD fail requests which do not pass their authorization checks with the <br> appropriate HTTP error code, or the 403 Forbidden error code where the existence of the object is considered private. <br> An origin server which does not wish to disclose the existence of a private target MAY instead respond with a status <br> code of 404 Not Found. <br>  |
| <span style='color: gray'>unknown</span> |  | [3.2](https://www.w3.org/TR/activitypub/#retrieving-objects) | should | Servers MAY require authorization as specified in B.1 Authentication and Authorization, and may additionally implement <br> their own authorization rules. Servers <mark>SHOULD</mark> fail requests which do not pass their authorization checks with the <br> appropriate HTTP error code, or the 403 Forbidden error code where the existence of the object is considered private. <br> An origin server which does not wish to disclose the existence of a private target MAY instead respond with a status <br> code of 404 Not Found. <br>  |
| <span style='color: gray'>unknown</span> |  | [3.2](https://www.w3.org/TR/activitypub/#retrieving-objects) | may | Servers MAY require authorization as specified in B.1 Authentication and Authorization, and may additionally implement <br> their own authorization rules. Servers SHOULD fail requests which do not pass their authorization checks with the <br> appropriate HTTP error code, or the 403 Forbidden error code where the existence of the object is considered private. <br> An origin server which does not wish to disclose the existence of a private target <mark>MAY</mark> instead respond with a status <br> code of 404 Not Found. <br>  |
| <span style='color: gray'>unknown</span> |  | [4](https://www.w3.org/TR/activitypub/#actors) | should | ActivityPub actors are generally one of the ActivityStreams Actor Types, but they don't have to be. For example, a <br> Profile object might be used as an actor, or a type from an ActivityStreams extension. Actors are retrieved like any <br> other Object in ActivityPub. Like other ActivityStreams objects, actors have an id, which is a URI. When entered <br> directly into a user interface (for example on a login form), it is desirable to support simplified naming. For this <br> purpose, ID normalization <mark>SHOULD</mark> be performed as follows: <br>  <br>   1. If the entered ID is a valid URI, then it is to be used directly. <br>   2. If it appears that the user neglected to add a scheme for a URI that would otherwise be considered valid, such as <br>      example.org/alice/, clients MAY attempt to provide a default scheme, preferably https. <br>   3. Otherwise, the entered value should be considered invalid. <br>  |
| <span style='color: gray'>unknown</span> |  | [4](https://www.w3.org/TR/activitypub/#actors) | may | ActivityPub actors are generally one of the ActivityStreams Actor Types, but they don't have to be. For example, a <br> Profile object might be used as an actor, or a type from an ActivityStreams extension. Actors are retrieved like any <br> other Object in ActivityPub. Like other ActivityStreams objects, actors have an id, which is a URI. When entered <br> directly into a user interface (for example on a login form), it is desirable to support simplified naming. For this <br> purpose, ID normalization SHOULD be performed as follows: <br>  <br>   1. If the entered ID is a valid URI, then it is to be used directly. <br>   2. If it appears that the user neglected to add a scheme for a URI that would otherwise be considered valid, such as <br>      example.org/alice/, clients <mark>MAY</mark> attempt to provide a default scheme, preferably https. <br>   3. Otherwise, the entered value should be considered invalid. <br>  |
| <span style='color: gray'>unknown</span> |  | [4.1](https://www.w3.org/TR/activitypub/#actor-objects) | must | Actor objects <mark>MUST</mark> have, in addition to the properties mandated by 3.1 Object Identifiers, the following properties: <br>  <br>   inbox <br>     A reference to an [ActivityStreams] OrderedCollection comprised of all the messages received by the actor; see 5.2 Inbox. <br>   outbox <br>     An [ActivityStreams] OrderedCollection comprised of all the messages produced by the actor; see 5.1 Outbox. <br>  |
| <span style='color: gray'>unknown</span> |  | [4.1](https://www.w3.org/TR/activitypub/#actor-objects) | should | Implementations <mark>SHOULD</mark>, in addition, provide the following properties: <br>  <br>   following <br>     A link to an [ActivityStreams] collection of the actors that this actor is following; see 5.4 Following Collection <br>   followers <br>     A link to an [ActivityStreams] collection of the actors that follow this actor; see 5.3 Followers Collection. <br>  |
| <span style='color: gray'>unknown</span> |  | [4.1](https://www.w3.org/TR/activitypub/#actor-objects) | may | Implementations <mark>MAY</mark> provide the following properties: <br>  <br>   liked <br>     A link to an [ActivityStreams] collection of objects this actor has liked; see 5.5 Liked Collection. <br>  |
| <span style='color: gray'>unknown</span> |  | [4.1](https://www.w3.org/TR/activitypub/#actor-objects) | may | Implementations <mark>MAY</mark>, in addition, provide the following properties: <br>  <br>   streams <br>     A list of supplementary Collections which may be of interest. <br>   preferredUsername <br>     A short username which may be used to refer to the actor, with no uniqueness guarantees. <br>   endpoints <br>     A json object which maps additional (typically server/domain-wide) endpoints which may be useful either for this <br>     actor or someone referencing this actor. This mapping may be nested inside the actor document as the value or may <br>     be a link to a JSON-LD document with these properties. <br>  |
| <span style='color: gray'>unknown</span> |  | [4.1](https://www.w3.org/TR/activitypub/#actor-objects) | may | The endpoints mapping <mark>MAY</mark> include the following properties: <br>  <br>   proxyUrl <br>     Endpoint URI so this actor's clients may access remote ActivityStreams objects which require authentication to <br>     access. To use this endpoint, the client posts an x-www-form-urlencoded id parameter with the value being the id <br>     of the requested ActivityStreams object. <br>   oauthAuthorizationEndpoint <br>     If OAuth 2.0 bearer tokens [RFC6749] [RFC6750] are being used for authenticating client to server interactions, <br>     this endpoint specifies a URI at which a browser-authenticated user may obtain a new authorization grant. <br>   oauthTokenEndpoint <br>     If OAuth 2.0 bearer tokens [RFC6749] [RFC6750] are being used for authenticating client to server interactions, <br>     this endpoint specifies a URI at which a client may acquire an access token. <br>   provideClientKey <br>     If Linked Data Signatures and HTTP Signatures are being used for authentication and authorization, this endpoint <br>     specifies a URI at which browser-authenticated users may authorize a client's public key for client to server <br>     interactions. <br>   signClientKey <br>     If Linked Data Signatures and HTTP Signatures are being used for authentication and authorization, this endpoint <br>     specifies a URI at which a client key may be signed by the actor's key for a time window to act on behalf of the <br>     actor in interacting with foreign servers. <br>   sharedInbox <br>     An optional endpoint used for wide delivery of publicly addressed activities and activities sent to followers. <br>     sharedInbox endpoints SHOULD also be publicly readable OrderedCollection objects containing objects addressed to <br>     the Public special collection. Reading from the sharedInbox endpoint MUST NOT present objects which are not addressed to the Public endpoint. <br>  |
| <span style='color: gray'>unknown</span> |  | [4.1](https://www.w3.org/TR/activitypub/#actor-objects) | should | sharedInbox <br>   An optional endpoint used for wide delivery of publicly addressed activities and activities sent to followers. <br>   sharedInbox endpoints <mark>SHOULD</mark> also be publicly readable OrderedCollection objects containing objects addressed to <br>   the Public special collection. Reading from the sharedInbox endpoint MUST NOT present objects which are not <br>   addressed to the Public endpoint. <br>  |
| <span style='color: gray'>unknown</span> |  | [4.1](https://www.w3.org/TR/activitypub/#actor-objects) | must_not | sharedInbox <br>   An optional endpoint used for wide delivery of publicly addressed activities and activities sent to followers. <br>   sharedInbox endpoints SHOULD also be publicly readable OrderedCollection objects containing objects addressed to <br>   the Public special collection. Reading from the sharedInbox endpoint <mark>MUST NOT</mark> present objects which are not <br>   addressed to the Public endpoint. <br>  |
| <span style='color: gray'>unknown</span> |  | [5](https://www.w3.org/TR/activitypub/#collections) | must | An OrderedCollection <mark>MUST</mark> be presented consistently in reverse chronological order <br>  |
| <span style='color: gray'>unknown</span> |  | [5.1](https://www.w3.org/TR/activitypub/#outbox) | must | The outbox is discovered through the outbox property of an actor's profile. <br> The outbox <mark>MUST</mark> be an OrderedCollection. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.2](https://www.w3.org/TR/activitypub/#inbox) | must | The inbox is discovered through the inbox property of an actor's profile. <br> The inbox <mark>MUST</mark> be an OrderedCollection. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.2](https://www.w3.org/TR/activitypub/#inbox) | should | The inbox stream contains all activities received by the actor. The server <mark>SHOULD</mark> filter content according to the <br> requester's permission. In general, the owner of an inbox is likely to be able to access all of their inbox contents. <br> Depending on access control, some other content may be public, whereas other content may require authentication for <br> non-owner users, if they can access the inbox at all. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.2](https://www.w3.org/TR/activitypub/#inbox) | must | The server <mark>MUST</mark> perform de-duplication of activities returned by the inbox. Duplication can occur if an activity is <br> addressed both to an actor's followers, and a specific actor who also follows the recipient actor, and the server has <br> failed to de-duplicate the recipients list. Such deduplication MUST be performed by comparing the id of the activities <br> and dropping any activities already seen. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.2](https://www.w3.org/TR/activitypub/#inbox) | must | The server MUST perform de-duplication of activities returned by the inbox. Duplication can occur if an activity is <br> addressed both to an actor's followers, and a specific actor who also follows the recipient actor, and the server has <br> failed to de-duplicate the recipients list. Such deduplication <mark>MUST</mark> be performed by comparing the id of the activities <br> and dropping any activities already seen. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.2](https://www.w3.org/TR/activitypub/#inbox) | should | The inboxes of actors on federated servers accepts HTTP POST requests, with behaviour described in Delivery. <br> Non-federated servers <mark>SHOULD</mark> return a 405 Method Not Allowed upon receipt of a POST request. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.3](https://www.w3.org/TR/activitypub/#followers) | should | Every actor <mark>SHOULD</mark> have a followers collection. This is a list of everyone who has sent a Follow activity for the <br> actor, added as a side effect. This is where one would find a list of all the actors that are following the actor. <br> The followers collection MUST be either an OrderedCollection or a Collection and MAY be filtered on privileges of an <br> authenticated user or as appropriate when no authentication is given. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.3](https://www.w3.org/TR/activitypub/#followers) | must | Every actor SHOULD have a followers collection. This is a list of everyone who has sent a Follow activity for the <br> actor, added as a side effect. This is where one would find a list of all the actors that are following the actor. <br> The followers collection <mark>MUST</mark> be either an OrderedCollection or a Collection and MAY be filtered on privileges of an <br> authenticated user or as appropriate when no authentication is given. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.4](https://www.w3.org/TR/activitypub/#following) | should | Every actor <mark>SHOULD</mark> have a following collection. This is a list of everybody that the actor has followed, added as a <br> side effect. The following collection MUST be either an OrderedCollection or a Collection and MAY be filtered on <br> privileges of an authenticated user or as appropriate when no authentication is given. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.4](https://www.w3.org/TR/activitypub/#following) | must | Every actor SHOULD have a following collection. This is a list of everybody that the actor has followed, added as a <br> side effect. The following collection <mark>MUST</mark> be either an OrderedCollection or a Collection and MAY be filtered on <br> privileges of an authenticated user or as appropriate when no authentication is given. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.4](https://www.w3.org/TR/activitypub/#following) | may | Every actor SHOULD have a following collection. This is a list of everybody that the actor has followed, added as a <br> side effect. The following collection MUST be either an OrderedCollection or a Collection and <mark>MAY</mark> be filtered on <br> privileges of an authenticated user or as appropriate when no authentication is given. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.5](https://www.w3.org/TR/activitypub/#liked) | may | Every actor <mark>MAY</mark> have a liked collection. This is a list of every object from all of the actor's Like activities, <br> added as a side effect. The liked collection MUST be either an OrderedCollection or a Collection and MAY be filtered <br> on privileges of an authenticated user or as appropriate when no authentication is given. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.5](https://www.w3.org/TR/activitypub/#liked) | must | Every actor MAY have a liked collection. This is a list of every object from all of the actor's Like activities, <br> added as a side effect. The liked collection <mark>MUST</mark> be either an OrderedCollection or a Collection and MAY be filtered <br> on privileges of an authenticated user or as appropriate when no authentication is given. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.5](https://www.w3.org/TR/activitypub/#liked) | may | Every actor MAY have a liked collection. This is a list of every object from all of the actor's Like activities, <br> added as a side effect. The liked collection MUST be either an OrderedCollection or a Collection and <mark>MAY</mark> be filtered <br> on privileges of an authenticated user or as appropriate when no authentication is given. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.6](https://www.w3.org/TR/activitypub/#public-addressing) | note | Activities addressed to this special URI shall be accessible to all users, without authentication. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.6](https://www.w3.org/TR/activitypub/#public-addressing) | must_not | Implementations <mark>MUST NOT</mark> deliver to the "public" special collection; it is not capable of receiving actual <br> activities. However, actors MAY have a sharedInbox endpoint which is available for efficient shared delivery of <br> public posts (as well as posts to followers-only); see 7.1.3 Shared Inbox Delivery. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.6](https://www.w3.org/TR/activitypub/#public-addressing) | may | Implementations MUST NOT deliver to the "public" special collection; it is not capable of receiving actual <br> activities. However, actors <mark>MAY</mark> have a sharedInbox endpoint which is available for efficient shared delivery of <br> public posts (as well as posts to followers-only); see 7.1.3 Shared Inbox Delivery. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.7](https://www.w3.org/TR/activitypub/#likes) | may | Every object <mark>MAY</mark> have a likes collection. This is a list of all Like activities with this object as the object <br> property, added as a side effect. The likes collection MUST be either an OrderedCollection or a Collection and MAY <br> be filtered on privileges of an authenticated user or as appropriate when no authentication is given. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.7](https://www.w3.org/TR/activitypub/#likes) | must | Every object MAY have a likes collection. This is a list of all Like activities with this object as the object <br> property, added as a side effect. The likes collection <mark>MUST</mark> be either an OrderedCollection or a Collection and MAY <br> be filtered on privileges of an authenticated user or as appropriate when no authentication is given. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.7](https://www.w3.org/TR/activitypub/#likes) | may | Every object MAY have a likes collection. This is a list of all Like activities with this object as the object <br> property, added as a side effect. The likes collection MUST be either an OrderedCollection or a Collection and <mark>MAY</mark> <br> be filtered on privileges of an authenticated user or as appropriate when no authentication is given. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.8](https://www.w3.org/TR/activitypub/#shares) | may | Every object <mark>MAY</mark> have a shares collection. This is a list of all Announce activities with this object as the object <br> property, added as a side effect. The shares collection MUST be either an OrderedCollection or a Collection and MAY <br> be filtered on privileges of an authenticated user or as appropriate when no authentication is given. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.8](https://www.w3.org/TR/activitypub/#shares) | must | Every object MAY have a shares collection. This is a list of all Announce activities with this object as the object <br> property, added as a side effect. The shares collection <mark>MUST</mark> be either an OrderedCollection or a Collection and MAY <br> be filtered on privileges of an authenticated user or as appropriate when no authentication is given. <br>  |
| <span style='color: gray'>unknown</span> |  | [5.8](https://www.w3.org/TR/activitypub/#shares) | may | Every object MAY have a shares collection. This is a list of all Announce activities with this object as the object <br> property, added as a side effect. The shares collection MUST be either an OrderedCollection or a Collection and <mark>MAY</mark> <br> be filtered on privileges of an authenticated user or as appropriate when no authentication is given. <br>  |
| <span style='color: gray'>unknown</span> |  | [7](https://www.w3.org/TR/activitypub/#server-to-server-interactions) | should | An Activity sent over the network <mark>SHOULD</mark> have an id, unless it is intended to be transient (in which case it MAY <br> omit the id). <br>  |
| <span style='color: gray'>unknown</span> |  | [7](https://www.w3.org/TR/activitypub/#server-to-server-interactions) | may | An Activity sent over the network SHOULD have an id, unless it is intended to be transient (in which case it <mark>MAY</mark> <br> omit the id). <br>  |
| <span style='color: gray'>unknown</span> |  | [7](https://www.w3.org/TR/activitypub/#server-to-server-interactions) | must | POST requests (eg. to the inbox) <mark>MUST</mark> be made with a Content-Type of <br> application/ld+json; profile="https://www.w3.org/ns/activitystreams" and GET requests (see also 3.2 Retrieving objects) <br> with an Accept header of application/ld+json; profile="https://www.w3.org/ns/activitystreams". <br>  |
| <span style='color: gray'>unknown</span> |  | [7](https://www.w3.org/TR/activitypub/#server-to-server-interactions) | should | Servers <mark>SHOULD</mark> interpret a Content-Type or Accept header of application/activity+json as equivalent to <br> application/ld+json; profile="https://www.w3.org/ns/activitystreams" for server-to-server interactions. <br>  |
| <span style='color: gray'>unknown</span> |  | [7](https://www.w3.org/TR/activitypub/#server-to-server-interactions) | must | Servers performing delivery to the inbox or sharedInbox properties of actors on other servers <mark>MUST</mark> provide the object <br> property in the activity: Create, Update, Delete, Follow, Add, Remove, Like, Block, Undo. Additionally, servers <br> performing server to server delivery of the following activities MUST also provide the target property: Add, Remove. <br>  |
| <span style='color: gray'>unknown</span> |  | [7](https://www.w3.org/TR/activitypub/#server-to-server-interactions) | must | Servers performing delivery to the inbox or sharedInbox properties of actors on other servers MUST provide the object <br> property in the activity: Create, Update, Delete, Follow, Add, Remove, Like, Block, Undo. Additionally, servers <br> performing server to server delivery of the following activities <mark>MUST</mark> also provide the target property: Add, Remove. <br>  |
| <span style='color: gray'>unknown</span> |  | [7](https://www.w3.org/TR/activitypub/#server-to-server-interactions) | should | HTTP caching mechanisms [RFC7234] <mark>SHOULD</mark> be respected when appropriate, both when receiving responses from other <br> servers as well as sending responses to other servers. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.1](https://www.w3.org/TR/activitypub/#delivery) | must | If a recipient is a Collection or OrderedCollection, then the server <mark>MUST</mark> dereference the collection (with the user's <br> credentials) and discover inboxes for each item in the collection. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.1](https://www.w3.org/TR/activitypub/#delivery) | must | Servers <mark>MUST</mark> limit the number of layers of indirections through collections <br> which will be performed, which MAY be one. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.1](https://www.w3.org/TR/activitypub/#delivery) | may | Servers MUST limit the number of layers of indirections through collections <br> which will be performed, which <mark>MAY</mark> be one. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.1](https://www.w3.org/TR/activitypub/#delivery) | must | Servers <mark>MUST</mark> de-duplicate the final recipient list. |
| <span style='color: gray'>unknown</span> |  | [7.1](https://www.w3.org/TR/activitypub/#delivery) | must | Servers <mark>MUST</mark> also exclude actors from the list which are the same as the actor of the Activity being notified about. <br> That is, actors shouldn't have their own activities delivered to themselves. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.1](https://www.w3.org/TR/activitypub/#delivery) | note | Attempts to deliver to an inbox on a non-federated server SHOULD result <br> in a 405 Method Not Allowed response. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.1](https://www.w3.org/TR/activitypub/#delivery) | should | For federated servers performing delivery to a third party server, delivery <mark>SHOULD</mark> be performed asynchronously, <br> and SHOULD additionally retry delivery to recipients if it fails due to network error. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.1](https://www.w3.org/TR/activitypub/#delivery) | should | For federated servers performing delivery to a third party server, delivery SHOULD be performed asynchronously, <br> and <mark>SHOULD</mark> additionally retry delivery to recipients if it fails due to network error. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.1.1](https://www.w3.org/TR/activitypub/#outbox-delivery) | must | When objects are received in the outbox (for servers which support both Client to Server interactions and Server to <br> Server Interactions), the server <mark>MUST</mark> target and deliver to: <br>  <br>   The to, bto, cc, bcc or audience fields if their values are individuals or Collections owned by the actor. <br>  <br>  |
| <span style='color: gray'>unknown</span> |  | [7.1.2](https://www.w3.org/TR/activitypub/#inbox-forwarding) | must | When Activities are received in the inbox, the server needs to forward these to recipients that the origin was unable <br> to deliver them to. To do this, the server <mark>MUST</mark> target and deliver to the values of to, cc, and/or audience if and <br> only if all of the following are true: <br>  <br>   This is the first time the server has seen this Activity. <br>   The values of to, cc, and/or audience contain a Collection owned by the server. <br>   The values of inReplyTo, object, target and/or tag are objects owned by the server. The server SHOULD recurse <br>     through these values to look for linked objects owned by the server, and SHOULD set a maximum limit for recursion <br>     (ie. the point at which the thread is so deep the recipients followers may not mind if they are no longer getting <br>     updates that don't directly involve the recipient). The server MUST only target the values of to, cc, and/or <br>     audience on the original object being forwarded, and not pick up any new addressees whilst recursing through the <br>     linked objects (in case these addressees were purposefully amended by or via the client). <br>  <br> The server MAY filter its delivery targets according to implementation-specific rules (for example, spam filtering). <br>  |
| <span style='color: gray'>unknown</span> |  | [7.1.2](https://www.w3.org/TR/activitypub/#inbox-forwarding) | should | When Activities are received in the inbox, the server needs to forward these to recipients that the origin was unable <br> to deliver them to. To do this, the server MUST target and deliver to the values of to, cc, and/or audience if and <br> only if all of the following are true: <br>  <br>   This is the first time the server has seen this Activity. <br>   The values of to, cc, and/or audience contain a Collection owned by the server. <br>   The values of inReplyTo, object, target and/or tag are objects owned by the server. The server <mark>SHOULD</mark> recurse <br>     through these values to look for linked objects owned by the server, and SHOULD set a maximum limit for recursion <br>     (ie. the point at which the thread is so deep the recipients followers may not mind if they are no longer getting <br>     updates that don't directly involve the recipient). The server MUST only target the values of to, cc, and/or <br>     audience on the original object being forwarded, and not pick up any new addressees whilst recursing through the <br>     linked objects (in case these addressees were purposefully amended by or via the client). <br>  <br> The server MAY filter its delivery targets according to implementation-specific rules (for example, spam filtering). <br>  |
| <span style='color: gray'>unknown</span> |  | [7.1.2](https://www.w3.org/TR/activitypub/#inbox-forwarding) | should | When Activities are received in the inbox, the server needs to forward these to recipients that the origin was unable <br> to deliver them to. To do this, the server MUST target and deliver to the values of to, cc, and/or audience if and <br> only if all of the following are true: <br>  <br>   This is the first time the server has seen this Activity. <br>   The values of to, cc, and/or audience contain a Collection owned by the server. <br>   The values of inReplyTo, object, target and/or tag are objects owned by the server. The server SHOULD recurse <br>     through these values to look for linked objects owned by the server, and <mark>SHOULD</mark> set a maximum limit for recursion <br>     (ie. the point at which the thread is so deep the recipients followers may not mind if they are no longer getting <br>     updates that don't directly involve the recipient). The server MUST only target the values of to, cc, and/or <br>     audience on the original object being forwarded, and not pick up any new addressees whilst recursing through the <br>     linked objects (in case these addressees were purposefully amended by or via the client). <br>  <br> The server MAY filter its delivery targets according to implementation-specific rules (for example, spam filtering). <br>  |
| <span style='color: gray'>unknown</span> |  | [7.1.2](https://www.w3.org/TR/activitypub/#inbox-forwarding) | must | When Activities are received in the inbox, the server needs to forward these to recipients that the origin was unable <br> to deliver them to. To do this, the server MUST target and deliver to the values of to, cc, and/or audience if and <br> only if all of the following are true: <br>  <br>   This is the first time the server has seen this Activity. <br>   The values of to, cc, and/or audience contain a Collection owned by the server. <br>   The values of inReplyTo, object, target and/or tag are objects owned by the server. The server SHOULD recurse <br>     through these values to look for linked objects owned by the server, and SHOULD set a maximum limit for recursion <br>     (ie. the point at which the thread is so deep the recipients followers may not mind if they are no longer getting <br>     updates that don't directly involve the recipient). The server <mark>MUST</mark> only target the values of to, cc, and/or <br>     audience on the original object being forwarded, and not pick up any new addressees whilst recursing through the <br>     linked objects (in case these addressees were purposefully amended by or via the client). <br>  <br> The server MAY filter its delivery targets according to implementation-specific rules (for example, spam filtering). <br>  |
| <span style='color: gray'>unknown</span> |  | [7.1.2](https://www.w3.org/TR/activitypub/#inbox-forwarding) | may | When Activities are received in the inbox, the server needs to forward these to recipients that the origin was unable <br> to deliver them to. To do this, the server MUST target and deliver to the values of to, cc, and/or audience if and <br> only if all of the following are true: <br>  <br>   This is the first time the server has seen this Activity. <br>   The values of to, cc, and/or audience contain a Collection owned by the server. <br>   The values of inReplyTo, object, target and/or tag are objects owned by the server. The server SHOULD recurse <br>     through these values to look for linked objects owned by the server, and SHOULD set a maximum limit for recursion <br>     (ie. the point at which the thread is so deep the recipients followers may not mind if they are no longer getting <br>     updates that don't directly involve the recipient). The server MUST only target the values of to, cc, and/or <br>     audience on the original object being forwarded, and not pick up any new addressees whilst recursing through the <br>     linked objects (in case these addressees were purposefully amended by or via the client). <br>  <br> The server <mark>MAY</mark> filter its delivery targets according to implementation-specific rules (for example, spam filtering). <br>  |
| <span style='color: gray'>unknown</span> |  | [7.1.3](https://www.w3.org/TR/activitypub/#shared-inbox-delivery) | may | When an object is being delivered to the originating actor's followers, a server <mark>MAY</mark> reduce the number of receiving <br> actors delivered to by identifying all followers which share the same sharedInbox who would otherwise be individual <br> recipients and instead deliver objects to said sharedInbox. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.1.3](https://www.w3.org/TR/activitypub/#shared-inbox-delivery) | may | Additionally, if an object is addressed to the Public special collection, a server <mark>MAY</mark> deliver that object to all <br> known sharedInbox endpoints on the network. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.1.3](https://www.w3.org/TR/activitypub/#shared-inbox-delivery) | must | Origin servers sending publicly addressed activities to sharedInbox endpoints <mark>MUST</mark> still deliver to actors and <br> collections otherwise addressed (through to, bto, cc, bcc, and audience) which do not have a sharedInbox and would <br> not otherwise receive the activity through the sharedInbox mechanism. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.3](https://www.w3.org/TR/activitypub/#update-activity-inbox) | should | For server to server interactions, an Update activity means that the receiving server <mark>SHOULD</mark> update its copy of the <br> object of the same id to the copy supplied in the Update activity. Unlike the client to server handling of the Update <br> activity, this is not a partial update but a complete replacement of the object. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.3](https://www.w3.org/TR/activitypub/#update-activity-inbox) | must | The receiving server <mark>MUST</mark> take care to be sure that the Update is authorized to modify its object. At minimum, this <br> may be done by ensuring that the Update and its object are of same origin. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.4](https://www.w3.org/TR/activitypub/#delete-activity-inbox) | should | The side effect of receiving this is that (assuming the object is owned by the sending actor / server) the server <br> receiving the delete activity <mark>SHOULD</mark> remove its representation of the object with the same id, and MAY replace that <br> representation with a Tombstone object. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.5](https://www.w3.org/TR/activitypub/#follow-activity-inbox) | should | The side effect of receiving this in an inbox is that the server <mark>SHOULD</mark> generate either an Accept or Reject activity <br> with the Follow as the object and deliver it to the actor of the Follow. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.5](https://www.w3.org/TR/activitypub/#follow-activity-inbox) | may | The Accept or Reject <mark>MAY</mark> be generated automatically, or MAY be the result of user input (possibly after some <br> delay in which the user reviews). <br>  |
| <span style='color: gray'>unknown</span> |  | [7.5](https://www.w3.org/TR/activitypub/#follow-activity-inbox) | may | The Accept or Reject MAY be generated automatically, or <mark>MAY</mark> be the result of user input (possibly after some <br> delay in which the user reviews). <br>  |
| <span style='color: gray'>unknown</span> |  | [7.5](https://www.w3.org/TR/activitypub/#follow-activity-inbox) | may | Servers <mark>MAY</mark> choose to not explicitly send a Reject in response to a Follow, though implementors ought to be aware <br> that the server sending the request could be left in an intermediate state. For example, a server might not send a <br> Reject to protect a user's privacy. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.5](https://www.w3.org/TR/activitypub/#follow-activity-inbox) | should | In the case of receiving an Accept referencing this Follow as the object, the server <mark>SHOULD</mark> add the actor to the <br> object actor's Followers Collection. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.5](https://www.w3.org/TR/activitypub/#follow-activity-inbox) | must_not | In the case of a Reject, the server <mark>MUST NOT</mark> add the actor to the object <br> actor''s Followers Collection. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.6](https://www.w3.org/TR/activitypub/#accept-activity-inbox) | should | If the object of an Accept received to an inbox is a Follow activity previously sent by the receiver, the server <br> <mark>SHOULD</mark> add the actor to the receiver's Following Collection. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.7](https://www.w3.org/TR/activitypub/#reject-activity-inbox) | must_not | If the object of a Reject received to an inbox is a Follow activity previously sent by the receiver, this means the <br> recipient did not approve the Follow request. The server <mark>MUST NOT</mark> add the actor to the receiver's Following <br> Collection. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.8](https://www.w3.org/TR/activitypub/#add-activity-inbox) | should | Upon receipt of a Remove activity into the inbox, the server <mark>SHOULD</mark> remove the object from the collection <br> specified in the target property, unless: <br>  <br>   the target is not owned by the receiving server, and thus they can't update it. <br>   the object is not allowed to be removed to the target collection for some other reason, at the receiver's discretion. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.10](https://www.w3.org/TR/activitypub/#like-activity-inbox) | should | The side effect of receiving this in an inbox is that the server <mark>SHOULD</mark> increment the object's count of likes by <br> adding the received activity to the likes collection if this collection is present. <br>  |
| <span style='color: gray'>unknown</span> |  | [7.11](https://www.w3.org/TR/activitypub/#announce-activity-inbox) | should | Upon receipt of an Announce activity in an inbox, a server <mark>SHOULD</mark> increment the object's count of shares by adding the <br> received activity to the shares collection if this collection is present. <br>  |
| <span style='color: gray'>unknown</span> |  | [B.7](https://www.w3.org/TR/activitypub/#security-federation-dos) | should | Servers <mark>SHOULD</mark> also take care not to overload servers with submissions, for example by using an exponential <br> backoff strategy. <br>  |

## <a id="objects__include_activitypub_context"></a><span style='color: gray'>○</span> `SHOULD` objects__include_activitypub_context

**Specification:** [3 - Objects](https://www.w3.org/TR/activitypub/#obj)

> ActivityPub defines some terms in addition to those provided by ActivityStreams. <br> These terms are provided in the ActivityPub JSON-LD context at https://www.w3.org/ns/activitystreams. <br> Implementers <mark>SHOULD</mark> include the ActivityPub context in their object definitions. <br> Implementers MAY include additional context as appropriate. <br> 

**No related examples**

## <a id="objects__include_additional_context"></a><span style='color: gray'>○</span> `MAY` objects__include_additional_context

**Specification:** [3 - Objects](https://www.w3.org/TR/activitypub/#obj)

> ActivityPub defines some terms in addition to those provided by ActivityStreams. <br> These terms are provided in the ActivityPub JSON-LD context at https://www.w3.org/ns/activitystreams. <br> Implementers SHOULD include the ActivityPub context in their object definitions. <br> Implementers <mark>MAY</mark> include additional context as appropriate. <br> 

**No related examples**

## <a id="objects__activitypub_share_activitystream_uri"></a><span style='color: gray'>○</span> `NOTE` objects__activitypub_share_activitystream_uri

**Specification:** [3 - Objects](https://www.w3.org/TR/activitypub/#obj)

> ActivityPub shares the same URI / IRI conventions as in ActivityStreams.

**No related examples**

## <a id="objects__validate_received_content"></a><span style='color: gray'>○</span> `SHOULD` objects__validate_received_content

**Specification:** [3 - Objects](https://www.w3.org/TR/activitypub/#obj)

> Servers <mark>SHOULD</mark> validate the content they receive to avoid content spoofing attacks. <br> (A server should do something at least as robust as checking that the object appears as received at its origin, but <br> mechanisms such as checking signatures would be better if available). No particular mechanism for verification is <br> authoritatively specified by this document, but please see Security Considerations for <br> some suggestions and good practices. <br> 

**No related examples**

## <a id="objects__objects_identifiers__unique"></a><span style='color: gray'>○</span> `MUST` objects__objects_identifiers__unique

**Specification:** [3.1 - Object Identifiers](https://www.w3.org/TR/activitypub/#obj-id)

> All Objects in [ActivityStreams] should have unique global identifiers. ActivityPub extends this requirement; all <br> objects distributed by the ActivityPub protocol <mark>MUST</mark> have unique global identifiers, unless they are intentionally <br> transient (short lived activities that are not intended to be able to be looked up, such as some kinds of chat <br> messages or game notifications). These identifiers must fall into one of the following groups: <br>  <br>   1. Publicly dereferencable URIs, such as HTTPS URIs, with their authority belonging to that of their originating server. (Publicly facing content SHOULD use HTTPS URIs). <br>   2. An ID explicitly specified as the JSON null object, which implies an anonymous object (a part of its parent context) <br> 

**No related examples**

## <a id="objects__objects_identifiers__use_https"></a><span style='color: gray'>○</span> `SHOULD` objects__objects_identifiers__use_https

**Specification:** [3.1 - Object Identifiers](https://www.w3.org/TR/activitypub/#obj-id)

> All Objects in [ActivityStreams] should have unique global identifiers. ActivityPub extends this requirement; all <br> objects distributed by the ActivityPub protocol MUST have unique global identifiers, unless they are intentionally <br> transient (short lived activities that are not intended to be able to be looked up, such as some kinds of chat <br> messages or game notifications). These identifiers must fall into one of the following groups: <br>  <br>   1. Publicly dereferencable URIs, such as HTTPS URIs, with their authority belonging to that of their originating server. (Publicly facing content <mark>SHOULD</mark> use HTTPS URIs). <br>   2. An ID explicitly specified as the JSON null object, which implies an anonymous object (a part of its parent context) <br> 

**No related examples**

## <a id="objects__objects_identifiers__provided_for_activities"></a><span style='color: gray'>○</span> `MUST` objects__objects_identifiers__provided_for_activities

**Specification:** [3.1 - Object Identifiers](https://www.w3.org/TR/activitypub/#obj-id)

> Identifiers <mark>MUST</mark> be provided for activities posted in server to server communication, unless the activity is <br> intentionally transient. However, for client to server communication, a server receiving an object posted to the <br> outbox with no specified id SHOULD allocate an object ID in the actor's namespace and attach it to the posted object. <br> 

**No related examples**

## <a id="objects__objects_identifiers__allocate_id"></a><span style='color: gray'>○</span> `SHOULD` objects__objects_identifiers__allocate_id

**Specification:** [3.1 - Object Identifiers](https://www.w3.org/TR/activitypub/#obj-id)

> Identifiers MUST be provided for activities posted in server to server communication, unless the activity is <br> intentionally transient. However, for client to server communication, a server receiving an object posted to the <br> outbox with no specified id <mark>SHOULD</mark> allocate an object ID in the actor's namespace and attach it to the posted object. <br> 

**No related examples**

## <a id="objects__objects_identifiers__omit_id"></a><span style='color: gray'>○</span> `MAY` objects__objects_identifiers__omit_id

**Specification:** [3.1 - Object Identifiers](https://www.w3.org/TR/activitypub/#obj-id)

> All objects have the following properties: <br>  <br> id <br>   The object's unique global identifier (unless the object is transient, in which case the id <mark>MAY</mark> be omitted). <br> type <br>   The type of the object. <br> 

**No related examples**

## <a id="objects__retrieving_objects__use_content_negociation"></a><span style='color: gray'>○</span> `MAY` objects__retrieving_objects__use_content_negociation

**Specification:** [3.2 - Retrieving objects](https://www.w3.org/TR/activitypub/#retrieving-objects)

> The HTTP GET method may be dereferenced against an object's id property to retrieve the activity. Servers <mark>MAY</mark> use HTTP <br> content negotiation as defined in [RFC7231] to select the type of data to return in response to a request, but MUST <br> present the ActivityStreams object representation in response to application/ld+json; <br> profile="https://www.w3.org/ns/activitystreams", and SHOULD also present the ActivityStreams representation in <br> response to application/activity+json as well. The client MUST specify an Accept header with the application/ld+json; <br> profile="https://www.w3.org/ns/activitystreams" media type in order to retrieve the activity. <br> 

**No related examples**

## <a id="objects__retrieving_objects__present_object_representation"></a><span style='color: gray'>○</span> `MUST` objects__retrieving_objects__present_object_representation

**Specification:** [3.2 - Retrieving objects](https://www.w3.org/TR/activitypub/#retrieving-objects)

> The HTTP GET method may be dereferenced against an object's id property to retrieve the activity. Servers MAY use HTTP <br> content negotiation as defined in [RFC7231] to select the type of data to return in response to a request, but <mark>MUST</mark> <br> present the ActivityStreams object representation in response to application/ld+json; <br> profile="https://www.w3.org/ns/activitystreams", and SHOULD also present the ActivityStreams representation in <br> response to application/activity+json as well. The client MUST specify an Accept header with the application/ld+json; <br> profile="https://www.w3.org/ns/activitystreams" media type in order to retrieve the activity. <br> 

**No related examples**

## <a id="objects__retrieving_objects__present_as_activity_json"></a><span style='color: gray'>○</span> `SHOULD` objects__retrieving_objects__present_as_activity_json

**Specification:** [3.2 - Retrieving objects](https://www.w3.org/TR/activitypub/#retrieving-objects)

> The HTTP GET method may be dereferenced against an object's id property to retrieve the activity. Servers MAY use HTTP <br> content negotiation as defined in [RFC7231] to select the type of data to return in response to a request, but MUST <br> present the ActivityStreams object representation in response to application/ld+json; <br> profile="https://www.w3.org/ns/activitystreams", and <mark>SHOULD</mark> also present the ActivityStreams representation in <br> response to application/activity+json as well. The client MUST specify an Accept header with the application/ld+json; <br> profile="https://www.w3.org/ns/activitystreams" media type in order to retrieve the activity. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [3.2 - Retrieving objects](https://www.w3.org/TR/activitypub/#retrieving-objects)

> The HTTP GET method may be dereferenced against an object's id property to retrieve the activity. Servers MAY use HTTP <br> content negotiation as defined in [RFC7231] to select the type of data to return in response to a request, but MUST <br> present the ActivityStreams object representation in response to application/ld+json; <br> profile="https://www.w3.org/ns/activitystreams", and SHOULD also present the ActivityStreams representation in <br> response to application/activity+json as well. The client <mark>MUST</mark> specify an Accept header with the application/ld+json; <br> profile="https://www.w3.org/ns/activitystreams" media type in order to retrieve the activity. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [3.2 - Retrieving objects](https://www.w3.org/TR/activitypub/#retrieving-objects)

> Servers <mark>MAY</mark> implement other behavior for requests which do not comply with the above requirement. (For example, <br> servers may implement additional legacy protocols, or may use the same URI for both HTML and ActivityStreams <br> representations of a resource). <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [3.2 - Retrieving objects](https://www.w3.org/TR/activitypub/#retrieving-objects)

> Servers <mark>MAY</mark> require authorization as specified in B.1 Authentication and Authorization, and may additionally implement <br> their own authorization rules. Servers SHOULD fail requests which do not pass their authorization checks with the <br> appropriate HTTP error code, or the 403 Forbidden error code where the existence of the object is considered private. <br> An origin server which does not wish to disclose the existence of a private target MAY instead respond with a status <br> code of 404 Not Found. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [3.2 - Retrieving objects](https://www.w3.org/TR/activitypub/#retrieving-objects)

> Servers MAY require authorization as specified in B.1 Authentication and Authorization, and may additionally implement <br> their own authorization rules. Servers <mark>SHOULD</mark> fail requests which do not pass their authorization checks with the <br> appropriate HTTP error code, or the 403 Forbidden error code where the existence of the object is considered private. <br> An origin server which does not wish to disclose the existence of a private target MAY instead respond with a status <br> code of 404 Not Found. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [3.2 - Retrieving objects](https://www.w3.org/TR/activitypub/#retrieving-objects)

> Servers MAY require authorization as specified in B.1 Authentication and Authorization, and may additionally implement <br> their own authorization rules. Servers SHOULD fail requests which do not pass their authorization checks with the <br> appropriate HTTP error code, or the 403 Forbidden error code where the existence of the object is considered private. <br> An origin server which does not wish to disclose the existence of a private target <mark>MAY</mark> instead respond with a status <br> code of 404 Not Found. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [4 - Actors](https://www.w3.org/TR/activitypub/#actors)

> ActivityPub actors are generally one of the ActivityStreams Actor Types, but they don't have to be. For example, a <br> Profile object might be used as an actor, or a type from an ActivityStreams extension. Actors are retrieved like any <br> other Object in ActivityPub. Like other ActivityStreams objects, actors have an id, which is a URI. When entered <br> directly into a user interface (for example on a login form), it is desirable to support simplified naming. For this <br> purpose, ID normalization <mark>SHOULD</mark> be performed as follows: <br>  <br>   1. If the entered ID is a valid URI, then it is to be used directly. <br>   2. If it appears that the user neglected to add a scheme for a URI that would otherwise be considered valid, such as <br>      example.org/alice/, clients MAY attempt to provide a default scheme, preferably https. <br>   3. Otherwise, the entered value should be considered invalid. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [4 - Actors](https://www.w3.org/TR/activitypub/#actors)

> ActivityPub actors are generally one of the ActivityStreams Actor Types, but they don't have to be. For example, a <br> Profile object might be used as an actor, or a type from an ActivityStreams extension. Actors are retrieved like any <br> other Object in ActivityPub. Like other ActivityStreams objects, actors have an id, which is a URI. When entered <br> directly into a user interface (for example on a login form), it is desirable to support simplified naming. For this <br> purpose, ID normalization SHOULD be performed as follows: <br>  <br>   1. If the entered ID is a valid URI, then it is to be used directly. <br>   2. If it appears that the user neglected to add a scheme for a URI that would otherwise be considered valid, such as <br>      example.org/alice/, clients <mark>MAY</mark> attempt to provide a default scheme, preferably https. <br>   3. Otherwise, the entered value should be considered invalid. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [4.1 - Actor objects](https://www.w3.org/TR/activitypub/#actor-objects)

> Actor objects <mark>MUST</mark> have, in addition to the properties mandated by 3.1 Object Identifiers, the following properties: <br>  <br>   inbox <br>     A reference to an [ActivityStreams] OrderedCollection comprised of all the messages received by the actor; see 5.2 Inbox. <br>   outbox <br>     An [ActivityStreams] OrderedCollection comprised of all the messages produced by the actor; see 5.1 Outbox. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [4.1 - Actor objects](https://www.w3.org/TR/activitypub/#actor-objects)

> Implementations <mark>SHOULD</mark>, in addition, provide the following properties: <br>  <br>   following <br>     A link to an [ActivityStreams] collection of the actors that this actor is following; see 5.4 Following Collection <br>   followers <br>     A link to an [ActivityStreams] collection of the actors that follow this actor; see 5.3 Followers Collection. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [4.1 - Actor objects](https://www.w3.org/TR/activitypub/#actor-objects)

> Implementations <mark>MAY</mark> provide the following properties: <br>  <br>   liked <br>     A link to an [ActivityStreams] collection of objects this actor has liked; see 5.5 Liked Collection. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [4.1 - Actor objects](https://www.w3.org/TR/activitypub/#actor-objects)

> Implementations <mark>MAY</mark>, in addition, provide the following properties: <br>  <br>   streams <br>     A list of supplementary Collections which may be of interest. <br>   preferredUsername <br>     A short username which may be used to refer to the actor, with no uniqueness guarantees. <br>   endpoints <br>     A json object which maps additional (typically server/domain-wide) endpoints which may be useful either for this <br>     actor or someone referencing this actor. This mapping may be nested inside the actor document as the value or may <br>     be a link to a JSON-LD document with these properties. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [4.1 - Actor objects](https://www.w3.org/TR/activitypub/#actor-objects)

> The endpoints mapping <mark>MAY</mark> include the following properties: <br>  <br>   proxyUrl <br>     Endpoint URI so this actor's clients may access remote ActivityStreams objects which require authentication to <br>     access. To use this endpoint, the client posts an x-www-form-urlencoded id parameter with the value being the id <br>     of the requested ActivityStreams object. <br>   oauthAuthorizationEndpoint <br>     If OAuth 2.0 bearer tokens [RFC6749] [RFC6750] are being used for authenticating client to server interactions, <br>     this endpoint specifies a URI at which a browser-authenticated user may obtain a new authorization grant. <br>   oauthTokenEndpoint <br>     If OAuth 2.0 bearer tokens [RFC6749] [RFC6750] are being used for authenticating client to server interactions, <br>     this endpoint specifies a URI at which a client may acquire an access token. <br>   provideClientKey <br>     If Linked Data Signatures and HTTP Signatures are being used for authentication and authorization, this endpoint <br>     specifies a URI at which browser-authenticated users may authorize a client's public key for client to server <br>     interactions. <br>   signClientKey <br>     If Linked Data Signatures and HTTP Signatures are being used for authentication and authorization, this endpoint <br>     specifies a URI at which a client key may be signed by the actor's key for a time window to act on behalf of the <br>     actor in interacting with foreign servers. <br>   sharedInbox <br>     An optional endpoint used for wide delivery of publicly addressed activities and activities sent to followers. <br>     sharedInbox endpoints SHOULD also be publicly readable OrderedCollection objects containing objects addressed to <br>     the Public special collection. Reading from the sharedInbox endpoint MUST NOT present objects which are not addressed to the Public endpoint. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [4.1 - Actor objects](https://www.w3.org/TR/activitypub/#actor-objects)

> sharedInbox <br>   An optional endpoint used for wide delivery of publicly addressed activities and activities sent to followers. <br>   sharedInbox endpoints <mark>SHOULD</mark> also be publicly readable OrderedCollection objects containing objects addressed to <br>   the Public special collection. Reading from the sharedInbox endpoint MUST NOT present objects which are not <br>   addressed to the Public endpoint. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST_NOT` 

**Specification:** [4.1 - Actor objects](https://www.w3.org/TR/activitypub/#actor-objects)

> sharedInbox <br>   An optional endpoint used for wide delivery of publicly addressed activities and activities sent to followers. <br>   sharedInbox endpoints SHOULD also be publicly readable OrderedCollection objects containing objects addressed to <br>   the Public special collection. Reading from the sharedInbox endpoint <mark>MUST NOT</mark> present objects which are not <br>   addressed to the Public endpoint. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [5 - Collections](https://www.w3.org/TR/activitypub/#collections)

> An OrderedCollection <mark>MUST</mark> be presented consistently in reverse chronological order <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [5.1 - Outbox](https://www.w3.org/TR/activitypub/#outbox)

> The outbox is discovered through the outbox property of an actor's profile. <br> The outbox <mark>MUST</mark> be an OrderedCollection. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [5.2 - Inbox](https://www.w3.org/TR/activitypub/#inbox)

> The inbox is discovered through the inbox property of an actor's profile. <br> The inbox <mark>MUST</mark> be an OrderedCollection. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [5.2 - Inbox](https://www.w3.org/TR/activitypub/#inbox)

> The inbox stream contains all activities received by the actor. The server <mark>SHOULD</mark> filter content according to the <br> requester's permission. In general, the owner of an inbox is likely to be able to access all of their inbox contents. <br> Depending on access control, some other content may be public, whereas other content may require authentication for <br> non-owner users, if they can access the inbox at all. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [5.2 - Inbox](https://www.w3.org/TR/activitypub/#inbox)

> The server <mark>MUST</mark> perform de-duplication of activities returned by the inbox. Duplication can occur if an activity is <br> addressed both to an actor's followers, and a specific actor who also follows the recipient actor, and the server has <br> failed to de-duplicate the recipients list. Such deduplication MUST be performed by comparing the id of the activities <br> and dropping any activities already seen. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [5.2 - Inbox](https://www.w3.org/TR/activitypub/#inbox)

> The server MUST perform de-duplication of activities returned by the inbox. Duplication can occur if an activity is <br> addressed both to an actor's followers, and a specific actor who also follows the recipient actor, and the server has <br> failed to de-duplicate the recipients list. Such deduplication <mark>MUST</mark> be performed by comparing the id of the activities <br> and dropping any activities already seen. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [5.2 - Inbox](https://www.w3.org/TR/activitypub/#inbox)

> The inboxes of actors on federated servers accepts HTTP POST requests, with behaviour described in Delivery. <br> Non-federated servers <mark>SHOULD</mark> return a 405 Method Not Allowed upon receipt of a POST request. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [5.3 - Followers Collection](https://www.w3.org/TR/activitypub/#followers)

> Every actor <mark>SHOULD</mark> have a followers collection. This is a list of everyone who has sent a Follow activity for the <br> actor, added as a side effect. This is where one would find a list of all the actors that are following the actor. <br> The followers collection MUST be either an OrderedCollection or a Collection and MAY be filtered on privileges of an <br> authenticated user or as appropriate when no authentication is given. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [5.3 - Followers Collection](https://www.w3.org/TR/activitypub/#followers)

> Every actor SHOULD have a followers collection. This is a list of everyone who has sent a Follow activity for the <br> actor, added as a side effect. This is where one would find a list of all the actors that are following the actor. <br> The followers collection <mark>MUST</mark> be either an OrderedCollection or a Collection and MAY be filtered on privileges of an <br> authenticated user or as appropriate when no authentication is given. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [5.4 - Following Collection](https://www.w3.org/TR/activitypub/#following)

> Every actor <mark>SHOULD</mark> have a following collection. This is a list of everybody that the actor has followed, added as a <br> side effect. The following collection MUST be either an OrderedCollection or a Collection and MAY be filtered on <br> privileges of an authenticated user or as appropriate when no authentication is given. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [5.4 - Following Collection](https://www.w3.org/TR/activitypub/#following)

> Every actor SHOULD have a following collection. This is a list of everybody that the actor has followed, added as a <br> side effect. The following collection <mark>MUST</mark> be either an OrderedCollection or a Collection and MAY be filtered on <br> privileges of an authenticated user or as appropriate when no authentication is given. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [5.4 - Following Collection](https://www.w3.org/TR/activitypub/#following)

> Every actor SHOULD have a following collection. This is a list of everybody that the actor has followed, added as a <br> side effect. The following collection MUST be either an OrderedCollection or a Collection and <mark>MAY</mark> be filtered on <br> privileges of an authenticated user or as appropriate when no authentication is given. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [5.5 - Liked Collection](https://www.w3.org/TR/activitypub/#liked)

> Every actor <mark>MAY</mark> have a liked collection. This is a list of every object from all of the actor's Like activities, <br> added as a side effect. The liked collection MUST be either an OrderedCollection or a Collection and MAY be filtered <br> on privileges of an authenticated user or as appropriate when no authentication is given. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [5.5 - Liked Collection](https://www.w3.org/TR/activitypub/#liked)

> Every actor MAY have a liked collection. This is a list of every object from all of the actor's Like activities, <br> added as a side effect. The liked collection <mark>MUST</mark> be either an OrderedCollection or a Collection and MAY be filtered <br> on privileges of an authenticated user or as appropriate when no authentication is given. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [5.5 - Liked Collection](https://www.w3.org/TR/activitypub/#liked)

> Every actor MAY have a liked collection. This is a list of every object from all of the actor's Like activities, <br> added as a side effect. The liked collection MUST be either an OrderedCollection or a Collection and <mark>MAY</mark> be filtered <br> on privileges of an authenticated user or as appropriate when no authentication is given. <br> 

**No related examples**

## <span style='color: gray'>○</span> `NOTE` 

**Specification:** [5.6 - Public Addressing](https://www.w3.org/TR/activitypub/#public-addressing)

> Activities addressed to this special URI shall be accessible to all users, without authentication. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST_NOT` 

**Specification:** [5.6 - Public Addressing](https://www.w3.org/TR/activitypub/#public-addressing)

> Implementations <mark>MUST NOT</mark> deliver to the "public" special collection; it is not capable of receiving actual <br> activities. However, actors MAY have a sharedInbox endpoint which is available for efficient shared delivery of <br> public posts (as well as posts to followers-only); see 7.1.3 Shared Inbox Delivery. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [5.6 - Public Addressing](https://www.w3.org/TR/activitypub/#public-addressing)

> Implementations MUST NOT deliver to the "public" special collection; it is not capable of receiving actual <br> activities. However, actors <mark>MAY</mark> have a sharedInbox endpoint which is available for efficient shared delivery of <br> public posts (as well as posts to followers-only); see 7.1.3 Shared Inbox Delivery. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [5.7 - Likes Collection](https://www.w3.org/TR/activitypub/#likes)

> Every object <mark>MAY</mark> have a likes collection. This is a list of all Like activities with this object as the object <br> property, added as a side effect. The likes collection MUST be either an OrderedCollection or a Collection and MAY <br> be filtered on privileges of an authenticated user or as appropriate when no authentication is given. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [5.7 - Likes Collection](https://www.w3.org/TR/activitypub/#likes)

> Every object MAY have a likes collection. This is a list of all Like activities with this object as the object <br> property, added as a side effect. The likes collection <mark>MUST</mark> be either an OrderedCollection or a Collection and MAY <br> be filtered on privileges of an authenticated user or as appropriate when no authentication is given. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [5.7 - Likes Collection](https://www.w3.org/TR/activitypub/#likes)

> Every object MAY have a likes collection. This is a list of all Like activities with this object as the object <br> property, added as a side effect. The likes collection MUST be either an OrderedCollection or a Collection and <mark>MAY</mark> <br> be filtered on privileges of an authenticated user or as appropriate when no authentication is given. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [5.8 - Shares Collection](https://www.w3.org/TR/activitypub/#shares)

> Every object <mark>MAY</mark> have a shares collection. This is a list of all Announce activities with this object as the object <br> property, added as a side effect. The shares collection MUST be either an OrderedCollection or a Collection and MAY <br> be filtered on privileges of an authenticated user or as appropriate when no authentication is given. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [5.8 - Shares Collection](https://www.w3.org/TR/activitypub/#shares)

> Every object MAY have a shares collection. This is a list of all Announce activities with this object as the object <br> property, added as a side effect. The shares collection <mark>MUST</mark> be either an OrderedCollection or a Collection and MAY <br> be filtered on privileges of an authenticated user or as appropriate when no authentication is given. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [5.8 - Shares Collection](https://www.w3.org/TR/activitypub/#shares)

> Every object MAY have a shares collection. This is a list of all Announce activities with this object as the object <br> property, added as a side effect. The shares collection MUST be either an OrderedCollection or a Collection and <mark>MAY</mark> <br> be filtered on privileges of an authenticated user or as appropriate when no authentication is given. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [7 - Server to Server Interactions](https://www.w3.org/TR/activitypub/#server-to-server-interactions)

> An Activity sent over the network <mark>SHOULD</mark> have an id, unless it is intended to be transient (in which case it MAY <br> omit the id). <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [7 - Server to Server Interactions](https://www.w3.org/TR/activitypub/#server-to-server-interactions)

> An Activity sent over the network SHOULD have an id, unless it is intended to be transient (in which case it <mark>MAY</mark> <br> omit the id). <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [7 - Server to Server Interactions](https://www.w3.org/TR/activitypub/#server-to-server-interactions)

> POST requests (eg. to the inbox) <mark>MUST</mark> be made with a Content-Type of <br> application/ld+json; profile="https://www.w3.org/ns/activitystreams" and GET requests (see also 3.2 Retrieving objects) <br> with an Accept header of application/ld+json; profile="https://www.w3.org/ns/activitystreams". <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [7 - Server to Server Interactions](https://www.w3.org/TR/activitypub/#server-to-server-interactions)

> Servers <mark>SHOULD</mark> interpret a Content-Type or Accept header of application/activity+json as equivalent to <br> application/ld+json; profile="https://www.w3.org/ns/activitystreams" for server-to-server interactions. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [7 - Server to Server Interactions](https://www.w3.org/TR/activitypub/#server-to-server-interactions)

> Servers performing delivery to the inbox or sharedInbox properties of actors on other servers <mark>MUST</mark> provide the object <br> property in the activity: Create, Update, Delete, Follow, Add, Remove, Like, Block, Undo. Additionally, servers <br> performing server to server delivery of the following activities MUST also provide the target property: Add, Remove. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [7 - Server to Server Interactions](https://www.w3.org/TR/activitypub/#server-to-server-interactions)

> Servers performing delivery to the inbox or sharedInbox properties of actors on other servers MUST provide the object <br> property in the activity: Create, Update, Delete, Follow, Add, Remove, Like, Block, Undo. Additionally, servers <br> performing server to server delivery of the following activities <mark>MUST</mark> also provide the target property: Add, Remove. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [7 - Server to Server Interactions](https://www.w3.org/TR/activitypub/#server-to-server-interactions)

> HTTP caching mechanisms [RFC7234] <mark>SHOULD</mark> be respected when appropriate, both when receiving responses from other <br> servers as well as sending responses to other servers. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [7.1 - Delivery](https://www.w3.org/TR/activitypub/#delivery)

> If a recipient is a Collection or OrderedCollection, then the server <mark>MUST</mark> dereference the collection (with the user's <br> credentials) and discover inboxes for each item in the collection. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [7.1 - Delivery](https://www.w3.org/TR/activitypub/#delivery)

> Servers <mark>MUST</mark> limit the number of layers of indirections through collections <br> which will be performed, which MAY be one. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [7.1 - Delivery](https://www.w3.org/TR/activitypub/#delivery)

> Servers MUST limit the number of layers of indirections through collections <br> which will be performed, which <mark>MAY</mark> be one. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [7.1 - Delivery](https://www.w3.org/TR/activitypub/#delivery)

> Servers <mark>MUST</mark> de-duplicate the final recipient list.

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [7.1 - Delivery](https://www.w3.org/TR/activitypub/#delivery)

> Servers <mark>MUST</mark> also exclude actors from the list which are the same as the actor of the Activity being notified about. <br> That is, actors shouldn't have their own activities delivered to themselves. <br> 

**No related examples**

## <span style='color: gray'>○</span> `NOTE` 

**Specification:** [7.1 - Delivery](https://www.w3.org/TR/activitypub/#delivery)

> Attempts to deliver to an inbox on a non-federated server SHOULD result <br> in a 405 Method Not Allowed response. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [7.1 - Delivery](https://www.w3.org/TR/activitypub/#delivery)

> For federated servers performing delivery to a third party server, delivery <mark>SHOULD</mark> be performed asynchronously, <br> and SHOULD additionally retry delivery to recipients if it fails due to network error. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [7.1 - Delivery](https://www.w3.org/TR/activitypub/#delivery)

> For federated servers performing delivery to a third party server, delivery SHOULD be performed asynchronously, <br> and <mark>SHOULD</mark> additionally retry delivery to recipients if it fails due to network error. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [7.1.1 - Outbox Delivery Requirements for Server to Server](https://www.w3.org/TR/activitypub/#outbox-delivery)

> When objects are received in the outbox (for servers which support both Client to Server interactions and Server to <br> Server Interactions), the server <mark>MUST</mark> target and deliver to: <br>  <br>   The to, bto, cc, bcc or audience fields if their values are individuals or Collections owned by the actor. <br>  <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [7.1.2 - Forwarding from Inbox](https://www.w3.org/TR/activitypub/#inbox-forwarding)

> When Activities are received in the inbox, the server needs to forward these to recipients that the origin was unable <br> to deliver them to. To do this, the server <mark>MUST</mark> target and deliver to the values of to, cc, and/or audience if and <br> only if all of the following are true: <br>  <br>   This is the first time the server has seen this Activity. <br>   The values of to, cc, and/or audience contain a Collection owned by the server. <br>   The values of inReplyTo, object, target and/or tag are objects owned by the server. The server SHOULD recurse <br>     through these values to look for linked objects owned by the server, and SHOULD set a maximum limit for recursion <br>     (ie. the point at which the thread is so deep the recipients followers may not mind if they are no longer getting <br>     updates that don't directly involve the recipient). The server MUST only target the values of to, cc, and/or <br>     audience on the original object being forwarded, and not pick up any new addressees whilst recursing through the <br>     linked objects (in case these addressees were purposefully amended by or via the client). <br>  <br> The server MAY filter its delivery targets according to implementation-specific rules (for example, spam filtering). <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [7.1.2 - Forwarding from Inbox](https://www.w3.org/TR/activitypub/#inbox-forwarding)

> When Activities are received in the inbox, the server needs to forward these to recipients that the origin was unable <br> to deliver them to. To do this, the server MUST target and deliver to the values of to, cc, and/or audience if and <br> only if all of the following are true: <br>  <br>   This is the first time the server has seen this Activity. <br>   The values of to, cc, and/or audience contain a Collection owned by the server. <br>   The values of inReplyTo, object, target and/or tag are objects owned by the server. The server <mark>SHOULD</mark> recurse <br>     through these values to look for linked objects owned by the server, and SHOULD set a maximum limit for recursion <br>     (ie. the point at which the thread is so deep the recipients followers may not mind if they are no longer getting <br>     updates that don't directly involve the recipient). The server MUST only target the values of to, cc, and/or <br>     audience on the original object being forwarded, and not pick up any new addressees whilst recursing through the <br>     linked objects (in case these addressees were purposefully amended by or via the client). <br>  <br> The server MAY filter its delivery targets according to implementation-specific rules (for example, spam filtering). <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [7.1.2 - Forwarding from Inbox](https://www.w3.org/TR/activitypub/#inbox-forwarding)

> When Activities are received in the inbox, the server needs to forward these to recipients that the origin was unable <br> to deliver them to. To do this, the server MUST target and deliver to the values of to, cc, and/or audience if and <br> only if all of the following are true: <br>  <br>   This is the first time the server has seen this Activity. <br>   The values of to, cc, and/or audience contain a Collection owned by the server. <br>   The values of inReplyTo, object, target and/or tag are objects owned by the server. The server SHOULD recurse <br>     through these values to look for linked objects owned by the server, and <mark>SHOULD</mark> set a maximum limit for recursion <br>     (ie. the point at which the thread is so deep the recipients followers may not mind if they are no longer getting <br>     updates that don't directly involve the recipient). The server MUST only target the values of to, cc, and/or <br>     audience on the original object being forwarded, and not pick up any new addressees whilst recursing through the <br>     linked objects (in case these addressees were purposefully amended by or via the client). <br>  <br> The server MAY filter its delivery targets according to implementation-specific rules (for example, spam filtering). <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [7.1.2 - Forwarding from Inbox](https://www.w3.org/TR/activitypub/#inbox-forwarding)

> When Activities are received in the inbox, the server needs to forward these to recipients that the origin was unable <br> to deliver them to. To do this, the server MUST target and deliver to the values of to, cc, and/or audience if and <br> only if all of the following are true: <br>  <br>   This is the first time the server has seen this Activity. <br>   The values of to, cc, and/or audience contain a Collection owned by the server. <br>   The values of inReplyTo, object, target and/or tag are objects owned by the server. The server SHOULD recurse <br>     through these values to look for linked objects owned by the server, and SHOULD set a maximum limit for recursion <br>     (ie. the point at which the thread is so deep the recipients followers may not mind if they are no longer getting <br>     updates that don't directly involve the recipient). The server <mark>MUST</mark> only target the values of to, cc, and/or <br>     audience on the original object being forwarded, and not pick up any new addressees whilst recursing through the <br>     linked objects (in case these addressees were purposefully amended by or via the client). <br>  <br> The server MAY filter its delivery targets according to implementation-specific rules (for example, spam filtering). <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [7.1.2 - Forwarding from Inbox](https://www.w3.org/TR/activitypub/#inbox-forwarding)

> When Activities are received in the inbox, the server needs to forward these to recipients that the origin was unable <br> to deliver them to. To do this, the server MUST target and deliver to the values of to, cc, and/or audience if and <br> only if all of the following are true: <br>  <br>   This is the first time the server has seen this Activity. <br>   The values of to, cc, and/or audience contain a Collection owned by the server. <br>   The values of inReplyTo, object, target and/or tag are objects owned by the server. The server SHOULD recurse <br>     through these values to look for linked objects owned by the server, and SHOULD set a maximum limit for recursion <br>     (ie. the point at which the thread is so deep the recipients followers may not mind if they are no longer getting <br>     updates that don't directly involve the recipient). The server MUST only target the values of to, cc, and/or <br>     audience on the original object being forwarded, and not pick up any new addressees whilst recursing through the <br>     linked objects (in case these addressees were purposefully amended by or via the client). <br>  <br> The server <mark>MAY</mark> filter its delivery targets according to implementation-specific rules (for example, spam filtering). <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [7.1.3 - Shared Inbox Delivery](https://www.w3.org/TR/activitypub/#shared-inbox-delivery)

> When an object is being delivered to the originating actor's followers, a server <mark>MAY</mark> reduce the number of receiving <br> actors delivered to by identifying all followers which share the same sharedInbox who would otherwise be individual <br> recipients and instead deliver objects to said sharedInbox. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [7.1.3 - Shared Inbox Delivery](https://www.w3.org/TR/activitypub/#shared-inbox-delivery)

> Additionally, if an object is addressed to the Public special collection, a server <mark>MAY</mark> deliver that object to all <br> known sharedInbox endpoints on the network. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [7.1.3 - Shared Inbox Delivery](https://www.w3.org/TR/activitypub/#shared-inbox-delivery)

> Origin servers sending publicly addressed activities to sharedInbox endpoints <mark>MUST</mark> still deliver to actors and <br> collections otherwise addressed (through to, bto, cc, bcc, and audience) which do not have a sharedInbox and would <br> not otherwise receive the activity through the sharedInbox mechanism. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [7.3 - Update Activity](https://www.w3.org/TR/activitypub/#update-activity-inbox)

> For server to server interactions, an Update activity means that the receiving server <mark>SHOULD</mark> update its copy of the <br> object of the same id to the copy supplied in the Update activity. Unlike the client to server handling of the Update <br> activity, this is not a partial update but a complete replacement of the object. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST` 

**Specification:** [7.3 - Update Activity](https://www.w3.org/TR/activitypub/#update-activity-inbox)

> The receiving server <mark>MUST</mark> take care to be sure that the Update is authorized to modify its object. At minimum, this <br> may be done by ensuring that the Update and its object are of same origin. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [7.4 - Delete Activity](https://www.w3.org/TR/activitypub/#delete-activity-inbox)

> The side effect of receiving this is that (assuming the object is owned by the sending actor / server) the server <br> receiving the delete activity <mark>SHOULD</mark> remove its representation of the object with the same id, and MAY replace that <br> representation with a Tombstone object. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [7.5 - Follow Activity](https://www.w3.org/TR/activitypub/#follow-activity-inbox)

> The side effect of receiving this in an inbox is that the server <mark>SHOULD</mark> generate either an Accept or Reject activity <br> with the Follow as the object and deliver it to the actor of the Follow. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [7.5 - Follow Activity](https://www.w3.org/TR/activitypub/#follow-activity-inbox)

> The Accept or Reject <mark>MAY</mark> be generated automatically, or MAY be the result of user input (possibly after some <br> delay in which the user reviews). <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [7.5 - Follow Activity](https://www.w3.org/TR/activitypub/#follow-activity-inbox)

> The Accept or Reject MAY be generated automatically, or <mark>MAY</mark> be the result of user input (possibly after some <br> delay in which the user reviews). <br> 

**No related examples**

## <span style='color: gray'>○</span> `MAY` 

**Specification:** [7.5 - Follow Activity](https://www.w3.org/TR/activitypub/#follow-activity-inbox)

> Servers <mark>MAY</mark> choose to not explicitly send a Reject in response to a Follow, though implementors ought to be aware <br> that the server sending the request could be left in an intermediate state. For example, a server might not send a <br> Reject to protect a user's privacy. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [7.5 - Follow Activity](https://www.w3.org/TR/activitypub/#follow-activity-inbox)

> In the case of receiving an Accept referencing this Follow as the object, the server <mark>SHOULD</mark> add the actor to the <br> object actor's Followers Collection. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST_NOT` 

**Specification:** [7.5 - Follow Activity](https://www.w3.org/TR/activitypub/#follow-activity-inbox)

> In the case of a Reject, the server <mark>MUST NOT</mark> add the actor to the object <br> actor''s Followers Collection. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [7.6 - Accept Activity](https://www.w3.org/TR/activitypub/#accept-activity-inbox)

> If the object of an Accept received to an inbox is a Follow activity previously sent by the receiver, the server <br> <mark>SHOULD</mark> add the actor to the receiver's Following Collection. <br> 

**No related examples**

## <span style='color: gray'>○</span> `MUST_NOT` 

**Specification:** [7.7 - Reject Activity](https://www.w3.org/TR/activitypub/#reject-activity-inbox)

> If the object of a Reject received to an inbox is a Follow activity previously sent by the receiver, this means the <br> recipient did not approve the Follow request. The server <mark>MUST NOT</mark> add the actor to the receiver's Following <br> Collection. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [7.8 - Add Activity](https://www.w3.org/TR/activitypub/#add-activity-inbox)

> Upon receipt of a Remove activity into the inbox, the server <mark>SHOULD</mark> remove the object from the collection <br> specified in the target property, unless: <br>  <br>   the target is not owned by the receiving server, and thus they can't update it. <br>   the object is not allowed to be removed to the target collection for some other reason, at the receiver's discretion. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [7.10 - Like Activity](https://www.w3.org/TR/activitypub/#like-activity-inbox)

> The side effect of receiving this in an inbox is that the server <mark>SHOULD</mark> increment the object's count of likes by <br> adding the received activity to the likes collection if this collection is present. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [7.11 - Announce Activity (sharing)](https://www.w3.org/TR/activitypub/#announce-activity-inbox)

> Upon receipt of an Announce activity in an inbox, a server <mark>SHOULD</mark> increment the object's count of shares by adding the <br> received activity to the shares collection if this collection is present. <br> 

**No related examples**

## <span style='color: gray'>○</span> `SHOULD` 

**Specification:** [B.7 - Federation denial-of-service](https://www.w3.org/TR/activitypub/#security-federation-dos)

> Servers <mark>SHOULD</mark> also take care not to overload servers with submissions, for example by using an exponential <br> backoff strategy. <br> 

**No related examples**
