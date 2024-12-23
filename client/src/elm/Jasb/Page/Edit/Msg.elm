module Jasb.Page.Edit.Msg exposing (Msg(..))

import Jasb.Bet.Editor.Model as BetEditor
import Jasb.Game.Editor.Model as GameEditor


type Msg
    = GameEditMsg GameEditor.Msg
    | BetEditMsg BetEditor.Msg
