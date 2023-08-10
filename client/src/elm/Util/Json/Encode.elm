module Util.Json.Encode exposing
    ( assocListToList
    , assocListToObject
    , atLeastOne
    , everySetToList
    , partialObject
    , posix
    )

import AssocList
import EverySet exposing (EverySet)
import Json.Encode exposing (..)
import Time


posix : Time.Posix -> Value
posix =
    Time.posixToMillis >> (\ms -> toFloat ms / 1000) >> float


atLeastOne : (value -> Value) -> ( value, List value ) -> Value
atLeastOne encodeValue ( head, tail ) =
    head :: tail |> list encodeValue


assocListToList : (key -> value -> Value) -> AssocList.Dict key value -> Value
assocListToList encodeEntry =
    AssocList.toList >> list (\( k, v ) -> encodeEntry k v)


assocListToObject : (key -> String) -> (value -> Value) -> AssocList.Dict key value -> Value
assocListToObject encodeKey encodeValue =
    let
        encodePair ( key, value ) =
            ( encodeKey key, encodeValue value )
    in
    AssocList.toList >> List.map encodePair >> object


everySetToList : (value -> Value) -> EverySet value -> Value
everySetToList encodeValue =
    EverySet.toList >> list encodeValue


partialObject : List ( String, Maybe Value ) -> Value
partialObject properties =
    let
        fromProperty ( name, maybeValue ) =
            maybeValue |> Maybe.map (Tuple.pair name)
    in
    properties |> List.filterMap fromProperty |> object
