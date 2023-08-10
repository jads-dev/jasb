module JoeBets.Navigation.Messages exposing (Msg(..))

import JoeBets.Navigation.Model exposing (..)


type Msg
    = OpenSubMenu SubMenu
    | CloseSubMenu SubMenu
