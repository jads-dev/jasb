module JoeBets.Page.Games.Model exposing
    ( Games
    , Model
    , Msg(..)
    , gamesDecoder
    )

import AssocList
import JoeBets.Api.Data as Api
import JoeBets.Api.Model as Api
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game exposing (Game)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Util.Json.Decode as JsonD


type alias Model =
    { games : Api.Data Games
    , favouritesOnly : Bool
    }


type alias Games =
    { future : AssocList.Dict Game.Id Game
    , current : AssocList.Dict Game.Id Game
    , finished : AssocList.Dict Game.Id Game
    }


gamesDecoder : JsonD.Decoder Games
gamesDecoder =
    let
        subsetDecoder =
            JsonD.assocListFromTupleList Game.idDecoder Game.decoder
    in
    JsonD.succeed Games
        |> JsonD.required "future" subsetDecoder
        |> JsonD.required "current" subsetDecoder
        |> JsonD.required "finished" subsetDecoder


type Msg
    = Load (Api.Response Games)
    | SetFavouritesOnly Bool
