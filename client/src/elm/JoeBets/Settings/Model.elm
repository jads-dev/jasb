module JoeBets.Settings.Model exposing
    ( Change(..)
    , Model
    , Msg(..)
    )

import JoeBets.Page.Bets.Filters exposing (Filters)
import JoeBets.Store.Item exposing (Item)


type Change
    = DefaultFiltersItem (Item Filters)


type Msg
    = SetDefaultFilters Filters
    | ReceiveChange Change
    | SetVisibility Bool


type alias Model =
    { visible : Bool
    , defaultFilters : Item Filters
    }
