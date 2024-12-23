module Jasb.Store.Session exposing
    ( delete
    , get
    , retrievedValues
    , set
    )

import Jasb.Ports as Ports
import Jasb.Store.Session.Model exposing (..)
import Json.Decode as JsonD
import Json.Encode as JsonE


get : Key -> Cmd msg
get =
    getOp >> Ports.sessionStoreCmd


set : KeyedValue -> Cmd msg
set kAndV =
    let
        ( key, maybeValue ) =
            keyAndValue kAndV
    in
    case maybeValue of
        Just value ->
            setOp key value |> Ports.sessionStoreCmd

        Nothing ->
            delete key


delete : Key -> Cmd msg
delete =
    deleteOp >> Ports.sessionStoreCmd


getOp : Key -> JsonE.Value
getOp key =
    [ ( "op", "Get" |> JsonE.string )
    , ( "key", key |> encodeKey )
    ]
        |> JsonE.object


setOp : Key -> JsonE.Value -> JsonE.Value
setOp key value =
    [ ( "op", "Set" |> JsonE.string )
    , ( "key", key |> encodeKey )
    , ( "value", value )
    ]
        |> JsonE.object


deleteOp : Key -> JsonE.Value
deleteOp key =
    [ ( "op", "Delete" |> JsonE.string )
    , ( "key", key |> encodeKey )
    ]
        |> JsonE.object


retrievedValues : (Result JsonD.Error KeyedValue -> msg) -> Sub msg
retrievedValues toMsg =
    JsonD.decodeValue valueDecoder |> Ports.sessionStoreSub |> Sub.map toMsg
