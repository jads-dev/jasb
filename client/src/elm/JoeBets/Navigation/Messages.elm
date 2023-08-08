module JoeBets.Navigation.Messages exposing (Msg(..))

import Material.Menu as Menu


type Msg
    = SetMoreSubmenuState Menu.State
    | SetUserSubmenuState Menu.State
