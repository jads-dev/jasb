module JoeBets.Page.Games.Model exposing
    ( Games
    , Model
    , Msg(..)
    , gamesDecoder
    )

import AssocList
import JoeBets.Game.Model as Game exposing (Game)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Util.Json.Decode as JsonD
import Util.RemoteData as RemoteData exposing (RemoteData)


type alias Model =
    { games : RemoteData Games
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
            JsonD.assocListFromList (JsonD.field "id" Game.idDecoder) (JsonD.field "game" Game.decoder)
    in
    JsonD.succeed Games
        |> JsonD.required "future" subsetDecoder
        |> JsonD.required "current" subsetDecoder
        |> JsonD.required "finished" subsetDecoder


type Msg
    = Load (RemoteData.Response Games)
    | SetFavouritesOnly Bool
