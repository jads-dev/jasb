module Jasb.Page.Gacha.PreviewBanner.Model exposing
    ( Model
    , decoder
    )

import Jasb.Gacha.Banner as Banner exposing (Banner)
import Jasb.Gacha.CardType as CardType
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD


type alias Model =
    { banner : Banner
    , cardTypes : CardType.CardTypes
    }


decoder : JsonD.Decoder Model
decoder =
    JsonD.succeed Model
        |> JsonD.required "banner" Banner.decoder
        |> JsonD.required "cardTypes" CardType.cardTypesDecoder
