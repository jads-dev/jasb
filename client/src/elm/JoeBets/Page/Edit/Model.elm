module JoeBets.Page.Edit.Model exposing
    ( Editor(..)
    , Model
    , Target(..)
    )

import JoeBets.Bet.Editor.Model as BetEditor
import JoeBets.Bet.Model as Bet
import JoeBets.Game.Editor.Model as GameEditor
import JoeBets.Game.Model as Game


type Target
    = Game (Maybe Game.Id)
    | Bet Game.Id (Maybe Bet.Id)


type Editor
    = GameEditor GameEditor.Model
    | BetEditor BetEditor.Model


type alias Model =
    Maybe Editor
