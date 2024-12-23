module Jasb.Navigation.Messages exposing (Msg(..))

import Jasb.Navigation.Model exposing (..)


type Msg
    = OpenSubMenu SubMenu
    | CloseSubMenu SubMenu
