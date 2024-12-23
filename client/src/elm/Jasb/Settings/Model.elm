module Jasb.Settings.Model exposing
    ( Change(..)
    , Model
    , Msg(..)
    )

import Jasb.Layout exposing (Layout)
import Jasb.Page.Bets.Filters exposing (Filters)
import Jasb.Store.Item exposing (Item)
import Jasb.Theme exposing (Theme)


type Change
    = DefaultFiltersItem (Item Filters)
    | ThemeItem (Item Theme)
    | LayoutItem (Item Layout)


type Msg
    = SetDefaultFilters Filters
    | SetTheme Theme
    | SetLayout Layout
    | ReceiveChange Change
    | SetVisibility Bool


type alias Model =
    { visible : Bool
    , defaultFilters : Item Filters
    , theme : Item Theme
    , layout : Item Layout
    }
