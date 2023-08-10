module JoeBets.Page.Bet.Model exposing
    ( GameAndBet
    , Model
    , Msg(..)
    , gameAndBetDecoder
    )

import JoeBets.Api.IdData as Api
import JoeBets.Api.Model as Api
import JoeBets.Bet.Model as Bet exposing (Bet)
import JoeBets.Bet.PlaceBet.Model as PlaceBet
import JoeBets.Feed.Model as Feed
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game exposing (Game)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD


type alias GameAndBetId =
    ( Game.Id, Bet.Id )


type alias GameAndBet =
    { game : Game
    , bet : Bet
    }


gameAndBetDecoder : JsonD.Decoder GameAndBet
gameAndBetDecoder =
    JsonD.succeed GameAndBet
        |> JsonD.required "game" Game.decoder
        |> JsonD.required "bet" Bet.decoder


type Msg
    = Load GameAndBetId (Api.Response GameAndBet)
    | Update GameAndBetId Bet
    | Apply (List PlaceBet.Change)
    | PlaceBetMsg PlaceBet.Msg
    | FeedMsg Feed.Msg


type alias Model =
    { data : Api.IdData GameAndBetId GameAndBet
    , placeBet : PlaceBet.Model
    , feed : Feed.Model
    }
