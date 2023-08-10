module JoeBets.Page.Gacha.Roll.Model exposing
    ( Model
    , Msg(..)
    , Progress(..)
    , Reveal
    , Roll
    , RollResult
    , rollResultDecoder
    )

import EverySet exposing (EverySet)
import JoeBets.Api.Model as Api
import JoeBets.Gacha.Balance as Balance exposing (Balance)
import JoeBets.Gacha.Balance.Rolls exposing (Rolls)
import JoeBets.Gacha.Banner as Banner
import JoeBets.Gacha.Card as Card
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD


type alias RollResult =
    { cards : Card.Cards
    , balance : Balance
    }


rollResultDecoder : JsonD.Decoder RollResult
rollResultDecoder =
    JsonD.succeed RollResult
        |> JsonD.required "cards" Card.cardsDecoder
        |> JsonD.required "balance" Balance.decoder


type Msg
    = DoRoll Banner.Id Rolls Bool
    | LoadRoll Banner.Id (Api.Response RollResult)
    | StartRevealing Banner.Id Card.Cards
    | RevealCard Card.Id
    | FinishRoll


type alias Roll =
    { cards : Maybe Card.Cards }


type alias Reveal =
    { cards : Card.Cards
    , revealed : EverySet Card.Id
    , focus : Maybe Card.Id
    }


type alias Review =
    { cards : Card.Cards
    , focus : Maybe Card.Id
    }


type Progress
    = Rolling Roll
    | Revealing Reveal
    | Reviewing Review


type alias Model =
    { banner : Banner.Id
    , progress : Progress
    }
