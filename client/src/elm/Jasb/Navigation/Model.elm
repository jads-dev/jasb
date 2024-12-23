module Jasb.Navigation.Model exposing
    ( Model
    , SubMenu(..)
    )


type SubMenu
    = MoreSubMenu
    | UserSubMenu


type alias Model =
    { openSubMenu : Maybe SubMenu }
