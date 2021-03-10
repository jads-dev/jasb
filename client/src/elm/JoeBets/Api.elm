module JoeBets.Api exposing
    ( delete
    , get
    , post
    , put
    )

import Http
import Url.Builder


get : String -> { path : List String, expect : Http.Expect msg } -> Cmd msg
get origin { path, expect } =
    request origin "GET" path Http.emptyBody expect


post : String -> { path : List String, body : Http.Body, expect : Http.Expect msg } -> Cmd msg
post origin { path, body, expect } =
    request origin "POST" path body expect


put : String -> { path : List String, body : Http.Body, expect : Http.Expect msg } -> Cmd msg
put origin { path, body, expect } =
    request origin "PUT" path body expect


delete : String -> { path : List String, body : Http.Body, expect : Http.Expect msg } -> Cmd msg
delete origin { path, body, expect } =
    request origin "DELETE" path body expect


request : String -> String -> List String -> Http.Body -> Http.Expect msg -> Cmd msg
request origin method path body expect =
    Http.riskyRequest
        { method = method
        , headers = []
        , url = url origin path
        , body = body
        , expect = expect
        , timeout = Nothing
        , tracker = Nothing
        }


url : String -> List String -> String
url origin path =
    if origin |> String.startsWith "localhost" then
        Url.Builder.crossOrigin "http://localhost:8081" ("api" :: path) []

    else
        Url.Builder.crossOrigin "https://api.jasb.900000000.xyz" ("api" :: path) []
