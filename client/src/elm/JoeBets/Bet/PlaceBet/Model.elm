module JoeBets.Bet.PlaceBet.Model exposing
    ( Change(..)
    , Dialog
    , Model
    , Msg(..)
    , Target
    )

import JoeBets.Api.Action as Api
import JoeBets.Api.Error as Api
import JoeBets.Bet.Model as Bet exposing (Bet)
import JoeBets.Bet.Option as Option
import JoeBets.Game.Id as Game
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
    | SetError Api.Error


type alias Dialog =
    { open : Bool
    , target : Target
    , amount : String
    , message : String
    , action : Api.ActionState
    }


type alias Model =
    Maybe Dialog


type Change
    = User User.Id User.Change
    | Bet Game.Id Bet.Id Bet.Change
