module JoeBets.Store.KeyedItem exposing (KeyedItem(..))

import JoeBets.Page.Bets.Model as Bets
import JoeBets.Settings.Model as Settings


type KeyedItem
    = SettingsItem Settings.Change
    | BetsItem Bets.StoreChange
