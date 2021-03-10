module Util.Json.Encode exposing
    ( assocListToList
    , atLeastOne
    , posix
    )

import AssocList
import Json.Encode exposing (..)
import Time


posix : Time.Posix -> Value
posix =
    Time.posixToMillis >> (\ms -> ms // 1000) >> int


atLeastOne : (value -> Value) -> ( value, List value ) -> Value
atLeastOne encodeValue ( head, tail ) =
    head :: tail |> list encodeValue


assocListToList : (key -> value -> Value) -> AssocList.Dict key value -> Value
assocListToList encodeEntry =
    AssocList.toList >> list (\( k, v ) -> encodeEntry k v)
