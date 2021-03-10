module JoeBets.Page.Bet.Model exposing
    ( Data
    , GameAndBet
    , Model
    , Msg(..)
    , gameAndBetDecoder
    )

import JoeBets.Bet.Model as Bet exposing (Bet)
import JoeBets.Bet.PlaceBet.Model as PlaceBet
import JoeBets.Game.Model as Game exposing (Game)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Util.RemoteData as RemoteData exposing (RemoteData)


type Msg
    = Load Game.Id Bet.Id (RemoteData.Response GameAndBet)
    | Update Game.Id Bet.Id Bet
    | PlaceBetMsg PlaceBet.Msg


type alias Data =
    { gameId : Game.Id
    , betId : Bet.Id
    , gameAndBet : RemoteData GameAndBet
    }


type alias GameAndBet =
    { game : Game
    , bet : Bet
    }


type alias Model =
    { data : Maybe Data
    , placeBet : PlaceBet.Model
    }


gameAndBetDecoder : JsonD.Decoder GameAndBet
gameAndBetDecoder =
    JsonD.succeed GameAndBet
        |> JsonD.required "game" Game.decoder
        |> JsonD.required "bet" Bet.decoder
