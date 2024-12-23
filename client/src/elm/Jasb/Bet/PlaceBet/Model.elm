module Jasb.Bet.PlaceBet.Model exposing
    ( Change(..)
    , Dialog
    , Model
    , Msg(..)
    , Target
    )

import Jasb.Api.Action as Api
import Jasb.Api.Error as Api
import Jasb.Bet.Model as Bet exposing (Bet)
import Jasb.Bet.Option as Option
import Jasb.Game.Id as Game
import Jasb.Page.User.Model as User
import Jasb.User.Model as User


type alias Target =
    { gameId : Game.Id
    , gameName : String
    , betId : Bet.Id
    , bet : Bet
    , optionId : Option.Id
    , optionName : String
    , existingStake : Maybe Int
    , existingOtherStakes : Int
    }


type Msg
    = Start Target
    | Cancel
    | ChangeAmount String
    | ChangeMessage String
    | Place User.WithId Int (Maybe String)
    | Withdraw User.Id
    | SetError Api.Error
    | NoOp


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
