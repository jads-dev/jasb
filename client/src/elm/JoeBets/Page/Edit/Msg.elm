module JoeBets.Page.Edit.Msg exposing (Msg(..))

import JoeBets.Bet.Editor.Model as BetEditor
import JoeBets.Game.Editor.Model as GameEditor
import JoeBets.Route exposing (Route)


type Msg
    = GameEditMsg GameEditor.Msg
    | BetEditMsg BetEditor.Msg
    | Save
    | Saved Route
    | NoOp
