module JoeBets.Store.Model exposing
    ( Key(..)
    , Value
    , encodeKey
    , keyDecoder
    )

import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game
import Json.Decode as JsonD
import Json.Encode as JsonE
import Util.Json.Decode as JsonD


type Key
    = DefaultFilters
    | Theme
    | Layout
    | GameFilters Game.Id
    | GameFavourites


keyDecoder : JsonD.Decoder Key
keyDecoder =
    let
        byName name =
            case String.split ":" name of
                [ "default-filters" ] ->
                    DefaultFilters |> JsonD.succeed

                [ "theme" ] ->
                    Theme |> JsonD.succeed

                [ "layout" ] ->
                    Layout |> JsonD.succeed

                [ "game-filters", game ] ->
                    game |> Game.idFromString |> GameFilters |> JsonD.succeed

                [ "game-favourites" ] ->
                    GameFavourites |> JsonD.succeed

                _ ->
                    name |> JsonD.unknownValue "store key"
    in
    JsonD.string |> JsonD.andThen byName


keyToString : Key -> String
keyToString =
    let
        toList key =
            case key of
                DefaultFilters ->
                    [ "default-filters" ]

                Theme ->
                    [ "theme" ]

                Layout ->
                    [ "layout" ]

                GameFilters gameId ->
                    [ "game-filters", gameId |> Game.idToString ]

                GameFavourites ->
                    [ "game-favourites" ]
    in
    toList >> String.join ":"


encodeKey : Key -> JsonE.Value
encodeKey =
    keyToString >> JsonE.string


type alias Value value =
    { key : Key
    , value : value
    , schemaVersion : Int
    , documentVersion : Int
    }
