module JoeBets.Bet.PlaceBet.Model exposing
    ( Model
    , Msg(..)
    , Overlay
    , Target
    )

import Http
import JoeBets.Bet.Model as Bet exposing (Bet)
import JoeBets.Bet.Option as Option
import JoeBets.Game.Model as Game


type alias Target =
    { gameId : Game.Id
    , gameName : String
    , betId : Bet.Id
    , bet : Bet
    , optionId : Option.Id
    , optionName : String
    , existingBet : Maybe Int
    }


type Msg
    = Start Target
    | Cancel
    | ChangeAmount String
    | Place Int
    | SetError Http.Error


type alias Overlay =
    { target : Target
    , amount : String
    , error : Maybe Http.Error
    }


type alias Model =
    Maybe Overlay
