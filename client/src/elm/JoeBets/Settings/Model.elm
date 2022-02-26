module JoeBets.Settings.Model exposing
    ( Change(..)
    , Model
    , Msg(..)
    )

import JoeBets.Layout exposing (Layout)
import JoeBets.Page.Bets.Filters exposing (Filters)
import JoeBets.Store.Item exposing (Item)
import JoeBets.Theme exposing (Theme)


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
