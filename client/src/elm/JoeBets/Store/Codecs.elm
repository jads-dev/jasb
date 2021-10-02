module JoeBets.Store.Codecs exposing
    ( defaultFilters
    , gameFavourites
    , gameFilters
    , itemDecoder
    , theme
    )

import EverySet exposing (EverySet)
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game
import JoeBets.Page.Bets.Filters as Filters exposing (Filters)
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Settings.Model as Settings
import JoeBets.Store.Item as Item
import JoeBets.Store.KeyedItem exposing (KeyedItem(..))
import JoeBets.Store.Model exposing (Key(..), keyDecoder)
import JoeBets.Theme as Theme exposing (Theme)
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


itemDecoder : JsonD.Decoder KeyedItem
itemDecoder =
    let
        fromKey key =
            case key of
                DefaultFilters ->
                    defaultFilters |> Item.itemDecoder |> JsonD.map (Settings.DefaultFiltersItem >> SettingsItem)

                Theme ->
                    theme |> Item.itemDecoder |> JsonD.map (Settings.ThemeItem >> SettingsItem)

                GameFilters gameId ->
                    gameId |> gameFilters |> Item.itemDecoder |> JsonD.map (Bets.FiltersItem gameId >> BetsItem)

                GameFavourites ->
                    gameFavourites |> Item.itemDecoder |> JsonD.map (Bets.FavouritesItem >> BetsItem)
    in
    JsonD.field "key" keyDecoder |> JsonD.andThen fromKey
