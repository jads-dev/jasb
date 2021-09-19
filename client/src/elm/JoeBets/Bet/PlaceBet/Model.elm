module JoeBets.Bet.PlaceBet.Model exposing
    ( Change(..)
    , Model
    , Msg(..)
    , Overlay
    , Target
    )

import Http
import JoeBets.Bet.Model as Bet exposing (Bet)
import JoeBets.Bet.Option as Option
import JoeBets.Game.Model as Game
import JoeBets.Page.User.Model as User
import JoeBets.User.Model as User


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
    | ChangeMessage String
    | Place User.WithId Int (Maybe String)
    | Withdraw User.Id
    | SetError Http.Error


type alias Overlay =
    { target : Target
    , amount : String
    , message : String
    , error : Maybe Http.Error
    }


type alias Model =
    Maybe Overlay


type Change
    = User User.Id User.Change
    | Bet Game.Id Bet.Id Bet.Change
