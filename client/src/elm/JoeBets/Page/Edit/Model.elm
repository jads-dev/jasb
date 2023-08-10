module JoeBets.Page.Edit.Model exposing
    ( EditMode(..)
    , Editor(..)
    , Model
    , Target(..)
    )

import JoeBets.Bet.Editor.Model as BetEditor
import JoeBets.Bet.Model as Bet
import JoeBets.Game.Editor.Model as GameEditor
import JoeBets.Game.Id as Game


type EditMode
    = New
    | Suggest
    | Edit Bet.Id


type Target
    = Game (Maybe Game.Id)
    | Bet Game.Id EditMode


type Editor
    = GameEditor GameEditor.Model
    | BetEditor BetEditor.Model


type alias Model =
    Maybe Editor
