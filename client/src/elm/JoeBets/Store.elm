module JoeBets.Store exposing
    ( changedValues
    , delete
    , get
    , init
    , set
    , setOrDelete
    )

import JoeBets.Ports as Ports
import JoeBets.Store.Codecs as Codecs
import JoeBets.Store.Item as Item exposing (Item)
import JoeBets.Store.KeyedItem exposing (KeyedItem)
import JoeBets.Store.Model exposing (Key)
import Json.Decode as JsonD


init : List JsonD.Value -> List KeyedItem
init items =
    let
        fromValue =
            JsonD.decodeValue Codecs.itemDecoder >> Result.toMaybe
    in
    items |> List.filterMap fromValue


get : Key -> Cmd msg
get =
    Item.get >> Ports.storeCmd


set : Item.Codec value -> Maybe (Item value) -> value -> Cmd msg
set codec oldValue value =
    Item.set codec oldValue value |> Ports.storeCmd


setOrDelete : Item.Codec value -> Maybe (Item value) -> Maybe value -> Cmd msg
setOrDelete codec oldValue value =
    case value of
        Just newValue ->
            set codec oldValue newValue

        Nothing ->
            delete codec oldValue


delete : Item.Codec value -> Maybe (Item value) -> Cmd msg
delete codec oldValue =
    Item.delete codec oldValue |> Ports.storeCmd


changedValues : (Result JsonD.Error KeyedItem -> msg) -> Sub msg
changedValues toMsg =
    JsonD.decodeValue Codecs.itemDecoder |> Ports.storeSub |> Sub.map toMsg
