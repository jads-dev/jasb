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
import Json.Decode as JsonD exposing (..)
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
    JsonD.list (JsonD.map2 Tuple.pair (JsonD.index 0 decodeKey) (JsonD.index 1 decodeValue))
        |> JsonD.map (List.reverse >> AssocList.fromList)


assocListFromList : Decoder key -> Decoder value -> Decoder (AssocList.Dict key value)
assocListFromList decodeKey decodeValue =
    JsonD.list (JsonD.map2 Tuple.pair decodeKey decodeValue) |> JsonD.map (List.reverse >> AssocList.fromList)


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


optionalAsMaybe : String -> JsonD.Decoder a -> Decoder (Maybe a -> b) -> JsonD.Decoder b
optionalAsMaybe key valDecoder decoder =
    JsonD.optional key (valDecoder |> JsonD.map Just) Nothing decoder


everySetFromList : JsonD.Decoder value -> JsonD.Decoder (EverySet value)
everySetFromList =
    JsonD.list >> JsonD.map EverySet.fromList
