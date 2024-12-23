module Jasb.Store.Codecs exposing
    ( defaultFilters
    , gameFavourites
    , gameFilters
    , itemDecoder
    , layout
    , theme
    )

import EverySet exposing (EverySet)
import Jasb.Game.Id as Game
import Jasb.Layout as Layout exposing (Layout)
import Jasb.Page.Bets.Filters as Filters exposing (Filters)
import Jasb.Page.Bets.Model as Bets
import Jasb.Settings.Model as Settings
import Jasb.Store.Item as Item
import Jasb.Store.KeyedItem exposing (KeyedItem(..))
import Jasb.Store.Model exposing (Key(..), keyDecoder)
import Jasb.Theme as Theme exposing (Theme)
import Json.Decode as JsonD
import Util.Json.Decode as JsonD
import Util.Json.Encode as JsonE


defaultFilters : Item.Codec Filters
defaultFilters =
    Item.initial DefaultFilters Filters.decoder Filters.encode Filters.init


gameFilters : Game.Id -> Item.Codec Filters
gameFilters gameId =
    Item.initial (GameFilters gameId) Filters.decoder Filters.encode Filters.init


gameFavourites : Item.Codec (EverySet Game.Id)
gameFavourites =
    Item.initial GameFavourites
        (JsonD.everySetFromList Game.idDecoder)
        (JsonE.everySetToList Game.encodeId)
        EverySet.empty


theme : Item.Codec Theme
theme =
    Item.initial Theme Theme.decoder Theme.encode Theme.Auto


layout : Item.Codec Layout
layout =
    Item.initial Layout Layout.decoder Layout.encode Layout.Auto


itemDecoder : JsonD.Decoder KeyedItem
itemDecoder =
    let
        fromKey key =
            case key of
                DefaultFilters ->
                    defaultFilters |> Item.itemDecoder |> JsonD.map (Settings.DefaultFiltersItem >> SettingsItem)

                Theme ->
                    theme |> Item.itemDecoder |> JsonD.map (Settings.ThemeItem >> SettingsItem)

                Layout ->
                    layout |> Item.itemDecoder |> JsonD.map (Settings.LayoutItem >> SettingsItem)

                GameFilters gameId ->
                    gameId |> gameFilters |> Item.itemDecoder |> JsonD.map (Bets.FiltersItem gameId >> BetsItem)

                GameFavourites ->
                    gameFavourites |> Item.itemDecoder |> JsonD.map (Bets.FavouritesItem >> BetsItem)
    in
    JsonD.field "key" keyDecoder |> JsonD.andThen fromKey
