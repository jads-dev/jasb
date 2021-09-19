module JoeBets.Game.Details exposing
    ( Detailed
    , Details
    , detailedDecoder
    , detailsDecoder
    )

import AssocList
import JoeBets.Game.Model as Game exposing (Game)
import JoeBets.User.Model as User
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Util.Json.Decode as JsonD


type alias Detailed =
    { game : Game
    , details : Details
    }


type alias Details =
    { mods : AssocList.Dict User.Id User.Summary
    , staked : Int
    }


detailsDecoder : JsonD.Decoder Details
detailsDecoder =
    JsonD.succeed Details
        |> JsonD.required "mods" (JsonD.assocListFromObject User.idFromString User.summaryDecoder)
        |> JsonD.required "staked" JsonD.int


detailedDecoder : JsonD.Decoder Detailed
detailedDecoder =
    JsonD.map2 Detailed
        Game.decoder
        detailsDecoder
