module Util.Http.StatusCodes exposing
    ( isInformational
    , continue, switchingProtocol, processing, earlyHints
    , isSuccessful
    , ok, created, accepted, nonAuthoritativeInformation, noContent, resetContent, partialContent, multiStatus, alreadyReported, imUsed
    , isRedirection
    , multipleChoice, movedPermanently, found, seeOther, notModified, useProxy, switchProxy, temporaryRedirect, permanentRedirect
    , isClientError
    , badRequest, unauthorized, paymentRequired, forbidden, notFound, methodNotAllowed, notAcceptable, proxyAuthenticationRequired, requestTimeout, conflict, gone, lengthRequired, preconditionFailed, payloadTooLarge, uriTooLong, unsupportedMediaType, rangeNotSatisfiable, expectationFailed, imATeapot, misdirectedRequest, unprocessableEntity, locked, failedDependency, tooEarly, upgradeRequired, preconditionRequired, tooManyRequests, requestHeaderFieldsTooLarge, unavailableForLegalReasons
    , isServerError
    , internalServerError, notImplemented, badGateway, serviceUnavailable, gatewayTimeout, httpVersionNotSupported, variantAlsoNegotiates, insufficientStorage, loopDetected, notExtended, networkAuthenticationRequired
    )

{-| Http Status Codes
Taken from <https://developer.mozilla.org/en-US/docs/Web/HTTP/Status>


# Informational

@docs isInformational
@docs continue, switchingProtocol, processing, earlyHints


# Successful

@docs isSuccessful
@docs ok, created, accepted, nonAuthoritativeInformation, noContent, resetContent, partialContent, multiStatus, alreadyReported, imUsed


# Redirection

@docs isRedirection
@docs multipleChoice, movedPermanently, found, seeOther, notModified, useProxy, switchProxy, temporaryRedirect, permanentRedirect


# Client Error

@docs isClientError
@docs badRequest, unauthorized, paymentRequired, forbidden, notFound, methodNotAllowed, notAcceptable, proxyAuthenticationRequired, requestTimeout, conflict, gone, lengthRequired, preconditionFailed, payloadTooLarge, uriTooLong, unsupportedMediaType, rangeNotSatisfiable, expectationFailed, imATeapot, misdirectedRequest, unprocessableEntity, locked, failedDependency, tooEarly, upgradeRequired, preconditionRequired, tooManyRequests, requestHeaderFieldsTooLarge, unavailableForLegalReasons


# Server Error

@docs isServerError
@docs internalServerError, notImplemented, badGateway, serviceUnavailable, gatewayTimeout, httpVersionNotSupported, variantAlsoNegotiates, insufficientStorage, loopDetected, notExtended, networkAuthenticationRequired

-}

{- Informational -}


{-| Returns true if the status code represents an informational response.
-}
isInformational : Int -> Bool
isInformational statusCode =
    statusCode >= 100 && statusCode < 200


{-| This interim response indicates that everything so far is OK and that the client should continue the request, or
ignore the response if the request is already finished.
-}
continue : Int
continue =
    100


{-| This code is sent in response to an Upgrade request header from the client, and indicates the protocol the server
is switching to.
-}
switchingProtocol : Int
switchingProtocol =
    101


{-| (WebDAV) This code indicates that the server has received and is processing the request, but no response is
available yet.
-}
processing : Int
processing =
    102


{-| This status code is primarily intended to be used with the `Link` header, letting the user agent start preloading
resources while the server prepares a response.
-}
earlyHints : Int
earlyHints =
    103



{- Successful -}


{-| Returns true if the status code represents a successful response.
-}
isSuccessful : Int -> Bool
isSuccessful statusCode =
    statusCode >= 200 && statusCode < 300


{-| The request has succeeded. The meaning of the success depends on the HTTP method:

  - `GET`: The resource has been fetched and is transmitted in the message body.
  - `HEAD`: The representation headers are included in the response without any message body.
  - `PUT` or `POST`: The resource describing the result of the action is transmitted in the message body.
  - `TRACE`: The message body contains the request message as received by the server.

-}
ok : Int
ok =
    200


{-| The request has succeeded and a new resource has been created as a result. This is typically the response sent
after `POST` requests, or some `PUT` requests.
-}
created : Int
created =
    201


{-| The request has been received but not yet acted upon. It is noncommittal, since there is no way in HTTP to later
send an asynchronous response indicating the outcome of the request. It is intended for cases where another process or
server handles the request, or for batch processing.
-}
accepted : Int
accepted =
    202


{-| This response code means the returned meta-information is not exactly the same as is available from the origin
server, but is collected from a local or a third-party copy. This is mostly used for mirrors or backups of another
resource. Except for that specific case, the [`ok`](#ok) response is preferred to this status.
-}
nonAuthoritativeInformation : Int
nonAuthoritativeInformation =
    203


{-| There is no content to send for this request, but the headers may be useful. The user-agent may update its cached
headers for this resource with the new ones.
-}
noContent : Int
noContent =
    204


{-| Tells the user-agent to reset the document which sent this request.
-}
resetContent : Int
resetContent =
    205


{-| This response code is used when the Range header is sent from the client to request only part of a resource.
-}
partialContent : Int
partialContent =
    206


{-| (WebDAV) Conveys information about multiple resources, for situations where multiple status codes might be
appropriate.
-}
multiStatus : Int
multiStatus =
    207


{-| (WebDAV) Used inside a `<dav:propstat>` response element to avoid repeatedly enumerating the internal members of
multiple bindings to the same collection.
-}
alreadyReported : Int
alreadyReported =
    208


{-| (WebDAV) The server has fulfilled a `GET` request for the resource, and the response is a representation of the
result of one or more instance-manipulations applied to the current instance.
-}
imUsed : Int
imUsed =
    226



{- Success -}


{-| Returns true if the status code represents a redirection response.
-}
isRedirection : Int -> Bool
isRedirection statusCode =
    statusCode >= 300 && statusCode < 400


{-| The request has more than one possible response. The user-agent or user should choose one of them. (There is no
standardized way of choosing one of the responses, but HTML links to the possibilities are recommended so the user can
pick.)
-}
multipleChoice : Int
multipleChoice =
    300


{-| The URL of the requested resource has been changed permanently. The new URL is given in the response.
-}
movedPermanently : Int
movedPermanently =
    301


{-| This response code means that the URI of requested resource has been changed temporarily. Further changes in the
URI might be made in the future. Therefore, this same URI should be used by the client in future requests.
@deprecated Superseded by [`seeOther`](#seeOther) and [`temporaryRedirect`](#temporaryRedirect).
-}
found : Int
found =
    302


{-| The server sent this response to direct the client to get the requested resource at another URI with a `GET`
request.
-}
seeOther : Int
seeOther =
    303


{-| This is used for caching purposes. It tells the client that the response has not been modified, so the client can
continue to use the same cached version of the response.
-}
notModified : Int
notModified =
    304


{-| Defined in a previous version of the HTTP specification to indicate that a requested response must be accessed by a
proxy.
@deprecated Due to security concerns regarding in-band configuration of a proxy.
-}
useProxy : Int
useProxy =
    305


{-| Originally meant "Subsequent requests should use the specified proxy.
@deprecated Removed from final version of the specification.
-}
switchProxy : Int
switchProxy =
    306


{-| The server sends this response to direct the client to get the requested resource at another URI with same method
that was used in the prior request. This has the same semantics as the [`found`](#found) HTTP response code, with the
exception that the user agent must not change the HTTP method used: If a `POST` was used in the first request, a `POST`
must be used in the second request.
-}
temporaryRedirect : Int
temporaryRedirect =
    307


{-| This means that the resource is now permanently located at another URI, specified by the Location: HTTP Response
header. This has the same semantics as the [`movedPermanently`](#movedPermanently) HTTP response code, with the
exception that the user agent must not change the HTTP method used: If a `POST` was used in the first request, a `POST`
must be used in the second request.
-}
permanentRedirect : Int
permanentRedirect =
    308



{- Client Error -}


{-| Returns true if the status code represents a client error response.
-}
isClientError : Int -> Bool
isClientError statusCode =
    statusCode >= 400 && statusCode < 500


{-| The server could not understand the request due to invalid syntax.
-}
badRequest : Int
badRequest =
    400


{-| Although the HTTP standard specifies "unauthorized", semantically this response means "unauthenticated". That is,
the client must authenticate itself to get the requested response.
-}
unauthorized : Int
unauthorized =
    401


{-| This response code is reserved for future use. The initial aim for creating this code was using it for digital
payment systems, however this status code is used very rarely and no standard convention exists.
-}
paymentRequired : Int
paymentRequired =
    402


{-| The client does not have access rights to the content; that is, it is unauthorized, so the server is refusing to
give the requested resource. Unlike [`unauthorized`](#unauthorized), the client's identity is known to the server.
-}
forbidden : Int
forbidden =
    403


{-| The server can not find the requested resource. In the browser, this means the URL is not recognized. In an
API, this can also mean that the endpoint is valid but the resource itself does not exist. Servers may also send
this response instead of [`forbidden`](#forbidden) to hide the existence of a resource from an unauthorized client.
This response code is probably the most famous one due to its frequent occurrence on the web.
-}
notFound : Int
notFound =
    404


{-| The request method is known by the server but is not supported by the target resource. For example, an API may
forbid `DELETE`-ing a resource.
-}
methodNotAllowed : Int
methodNotAllowed =
    405


{-| This response is sent when the web server, after performing server-driven content negotiation, doesn't find any
content that conforms to the criteria given by the user agent.
-}
notAcceptable : Int
notAcceptable =
    406


{-| This is similar to [`authenticationRequired`](#authenticationRequired) but authentication is needed to be done by
a proxy.
-}
proxyAuthenticationRequired : Int
proxyAuthenticationRequired =
    407


{-| This response is sent on an idle connection by some servers, even without any previous request by the client. It
means that the server would like to shut down this unused connection. This response is used much more since some
browsers, like Chrome, Firefox 27+, or IE9, use HTTP pre-connection mechanisms to speed up surfing. Also note that
some servers merely shut down the connection without sending this message.
-}
requestTimeout : Int
requestTimeout =
    408


{-| This response is sent when a request conflicts with the current state of the server.
-}
conflict : Int
conflict =
    409


{-| This response is sent when the requested content has been permanently deleted from server, with no forwarding
address. Clients are expected to remove their caches and links to the resource. The HTTP specification intends this
status code to be used for "limited-time, promotional services". APIs should not feel compelled to indicate resources
that have been deleted with this status code.
-}
gone : Int
gone =
    410


{-| Server rejected the request because the `Content-Length` header field is not defined and the server requires it.
-}
lengthRequired : Int
lengthRequired =
    411


{-| The client has indicated preconditions in its headers which the server does not meet.
-}
preconditionFailed : Int
preconditionFailed =
    412


{-| Request entity is larger than limits defined by server; the server might close the connection or return an
`Retry-After` header field.
-}
payloadTooLarge : Int
payloadTooLarge =
    413


{-| The URI requested by the client is longer than the server is willing to interpret.
-}
uriTooLong : Int
uriTooLong =
    414


{-| The media format of the requested data is not supported by the server, so the server is rejecting the request.
-}
unsupportedMediaType : Int
unsupportedMediaType =
    415


{-| The range specified by the `Range` header field in the request can't be fulfilled; it's possible that the range
is outside the size of the target URI's data.
-}
rangeNotSatisfiable : Int
rangeNotSatisfiable =
    416


{-| This response code means the expectation indicated by the `Expect` request header field can't be met by the server.
-}
expectationFailed : Int
expectationFailed =
    417


{-| The server refuses the attempt to brew coffee with a teapot.
-}
imATeapot : Int
imATeapot =
    418


{-| The request was directed at a server that is not able to produce a response. This can be sent by a server that
is not configured to produce responses for the combination of scheme and authority that are included in the request URI.
-}
misdirectedRequest : Int
misdirectedRequest =
    421


{-| (WebDAV) The request was well-formed but was unable to be followed due to semantic errors.
-}
unprocessableEntity : Int
unprocessableEntity =
    422


{-| (WebDAV) The resource that is being accessed is locked.
-}
locked : Int
locked =
    423


{-| (WebDAV) The request failed due to failure of a previous request.
-}
failedDependency : Int
failedDependency =
    424


{-| Indicates that the server is unwilling to risk processing a request that might be replayed.
-}
tooEarly : Int
tooEarly =
    425


{-| The server refuses to perform the request using the current protocol but might be willing to do so after the
client upgrades to a different protocol. The server sends an `Upgrade` header in a 426 response to indicate the
required protocol(s).
-}
upgradeRequired : Int
upgradeRequired =
    426


{-| The origin server requires the request to be conditional. This response is intended to prevent the 'lost update'
problem, where a client `GET`s a resource's state, modifies it, and `PUT`s it back to the server, when meanwhile a
third party has modified the state on the server, leading to a conflict.
-}
preconditionRequired : Int
preconditionRequired =
    428


{-| The user has sent too many requests in a given amount of time ("rate limiting").
-}
tooManyRequests : Int
tooManyRequests =
    429


{-| The server is unwilling to process the request because its header fields are too large. The request may be
resubmitted after reducing the size of the request header fields.
-}
requestHeaderFieldsTooLarge : Int
requestHeaderFieldsTooLarge =
    431


{-| The user-agent requested a resource that cannot legally be provided, such as a web page censored by a government.
-}
unavailableForLegalReasons : Int
unavailableForLegalReasons =
    451



{- Server Error -}


{-| Returns true if the status code represents a server error response.
-}
isServerError : Int -> Bool
isServerError statusCode =
    statusCode >= 500 && statusCode < 600


{-| The server has encountered a situation it doesn't know how to handle.
-}
internalServerError : Int
internalServerError =
    500


{-| The request method is not supported by the server and cannot be handled. The only methods that servers are
required to support (and therefore that must not return this code) are `GET` and `HEAD`.
-}
notImplemented : Int
notImplemented =
    501


{-| This error response means that the server, while working as a gateway to get a response needed to handle the
request, got an invalid response.
-}
badGateway : Int
badGateway =
    502


{-| The server is not ready to handle the request. Common causes are a server that is down for maintenance or that
is overloaded. Note that together with this response, a user-friendly page explaining the problem should be sent.
This response should be used for temporary conditions and the `Retry-After:` HTTP header should, if possible, contain
he estimated time before the recovery of the service. The webmaster must also take care about the caching-related
headers that are sent along with this response, as these temporary condition responses should usually not be cached.
-}
serviceUnavailable : Int
serviceUnavailable =
    503


{-| This error response is given when the server is acting as a gateway and cannot get a response in time.
-}
gatewayTimeout : Int
gatewayTimeout =
    504


{-| The HTTP version used in the request is not supported by the server.
-}
httpVersionNotSupported : Int
httpVersionNotSupported =
    505


{-| The server has an internal configuration error: the chosen variant resource is configured to engage in
transparent content negotiation itself, and is therefore not a proper end point in the negotiation process.
-}
variantAlsoNegotiates : Int
variantAlsoNegotiates =
    506


{-| (WebDAV) The method could not be performed on the resource because the server is unable to store the
representation needed to successfully complete the request.
-}
insufficientStorage : Int
insufficientStorage =
    507


{-| (WebDAV) The server detected an infinite loop while processing the request.
-}
loopDetected : Int
loopDetected =
    508


{-| Further extensions to the request are required for the server to fulfill it.
-}
notExtended : Int
notExtended =
    510


{-| The 511 status code indicates that the client needs to authenticate to gain network access.
-}
networkAuthenticationRequired : Int
networkAuthenticationRequired =
    511
