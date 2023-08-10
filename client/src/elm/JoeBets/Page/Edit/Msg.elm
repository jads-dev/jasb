module JoeBets.Page.Edit.Msg exposing (Msg(..))

import JoeBets.Bet.Editor.Model as BetEditor
import JoeBets.Game.Editor.Model as GameEditor


type Msg
    = GameEditMsg GameEditor.Msg
    | BetEditMsg BetEditor.Msg
