module Jasb.Store.KeyedItem exposing (KeyedItem(..))

import Jasb.Page.Bets.Model as Bets
import Jasb.Settings.Model as Settings


type KeyedItem
    = SettingsItem Settings.Change
    | BetsItem Bets.StoreChange
