module Jasb.Page.Edit.Model exposing
    ( EditMode(..)
    , Editor(..)
    , Model
    , Target(..)
    )

import Jasb.Bet.Editor.Model as BetEditor
import Jasb.Bet.Model as Bet
import Jasb.Game.Editor.Model as GameEditor
import Jasb.Game.Id as Game


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
