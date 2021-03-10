module JoeBets.Bet.Editor.Model exposing
    ( Model
    , Msg(..)
    )

import JoeBets.Bet.Editor.OptionEditor as OptionEditor
import JoeBets.Bet.Editor.ProgressEditor as ProgressEditor
import JoeBets.Bet.Model as Bet exposing (Bet)
import JoeBets.Game.Model as Game exposing (Game)
import JoeBets.Page.Bet.Model as Bet
import Util.RemoteData as RemoteData exposing (RemoteData)


type alias Model =
    { source : Maybe ( Bet.Id, RemoteData Bet.GameAndBet )
    , gameId : Game.Id
    , name : String
    , description : String
    , progress : ProgressEditor.Model
    , spoiler : Bool
    , options : List OptionEditor.Model
    }


type Msg
    = Load Game.Id Bet.Id (RemoteData.Response Bet.GameAndBet)
    | Reset
    | ChangeName String
    | ChangeDescription String
    | ChangeSpoiler Bool
    | AddOption
    | DeleteOption Int
    | OptionEditorMsg Int OptionEditor.Msg
    | ReorderOption Int Int
    | ProgressEditorMsg ProgressEditor.Msg
    | NoOp
