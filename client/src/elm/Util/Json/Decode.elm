module Util.Json.Decode exposing
    ( assocListFromList
    , assocListFromObject
    , assocListFromTupleList
    , atLeastOne
    , everySetFromList
    , optionalAsMaybe
    , unknownValue
    )

import AssocList
import Dict
import EverySet exposing (EverySet)
import Json.Decode exposing (..)
import Json.Decode.Pipeline as JsonD


atLeastOne : Decoder a -> Decoder ( a, List a )
atLeastOne itemDecoder =
    let
        nonEmpty items =
            case items of
                [] ->
                    fail "cannot be empty"

                first :: rest ->
                    succeed ( first, rest )
    in
    list itemDecoder |> andThen nonEmpty


assocListFromTupleList : Decoder key -> Decoder value -> Decoder (AssocList.Dict key value)
assocListFromTupleList decodeKey decodeValue =
    list (map2 Tuple.pair (index 0 decodeKey) (index 1 decodeValue))
        |> map (List.reverse >> AssocList.fromList)


assocListFromList : Decoder key -> Decoder value -> Decoder (AssocList.Dict key value)
assocListFromList decodeKey decodeValue =
    list (map2 Tuple.pair decodeKey decodeValue) |> map (List.reverse >> AssocList.fromList)


assocListFromObject : (String -> key) -> Decoder value -> Decoder (AssocList.Dict key value)
assocListFromObject keyFromString valueDecoder =
    let
        wrapKey ( key, value ) =
            ( keyFromString key, value )

        convert dict =
            dict |> Dict.toList |> List.map wrapKey |> List.reverse |> AssocList.fromList
    in
    dict valueDecoder |> map convert


unknownValue : String -> String -> Decoder a
unknownValue name value =
    ("Unknown " ++ name ++ ": \"" ++ value ++ "\".") |> fail


optionalAsMaybe : String -> Decoder a -> Decoder (Maybe a -> b) -> Decoder b
optionalAsMaybe key valDecoder decoder =
    JsonD.optional key (valDecoder |> map Just) Nothing decoder


everySetFromList : Decoder value -> Decoder (EverySet value)
everySetFromList =
    list >> map EverySet.fromList
