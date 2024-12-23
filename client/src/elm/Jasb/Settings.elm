module Jasb.Settings exposing
    ( init
    , update
    , view
    )

import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Jasb.Layout as Layout
import Jasb.Page.Bets.Filters as Filters
import Jasb.Settings.Model exposing (..)
import Jasb.Store as Store
import Jasb.Store.Codecs as Codecs
import Jasb.Store.Item as Item
import Jasb.Store.KeyedItem as Store exposing (KeyedItem)
import Jasb.Theme as Theme
import Material.Button as Button
import Material.Chips as Chips
import Material.Chips.Filter as FilterChip
import Material.Dialog as Dialog


type alias Parent a =
    { a | settings : Model }


init : List KeyedItem -> Model
init storeData =
    let
        fromItem keyedItem =
            case keyedItem of
                Store.SettingsItem change ->
                    Just change

                _ ->
                    Nothing

        model =
            { visible = False
            , defaultFilters = Item.default Codecs.defaultFilters
            , theme = Item.default Codecs.theme
            , layout = Item.default Codecs.layout
            }
    in
    storeData |> List.filterMap fromItem |> List.foldl apply model


update : Msg -> Parent a -> ( Parent a, Cmd msg )
update msg ({ settings } as model) =
    case msg of
        SetDefaultFilters filters ->
            ( model, Store.set Codecs.defaultFilters (Just settings.defaultFilters) filters )

        SetTheme theme ->
            ( model, Store.set Codecs.theme (Just settings.theme) theme )

        SetLayout layout ->
            ( model, Store.set Codecs.layout (Just settings.layout) layout )

        ReceiveChange change ->
            ( { model | settings = settings |> apply change }, Cmd.none )

        SetVisibility visible ->
            ( { model | settings = { settings | visible = visible } }, Cmd.none )


view : (Msg -> msg) -> Parent a -> List (Html msg)
view wrap { settings } =
    let
        filters =
            settings.defaultFilters.value

        setFilter filter toggle =
            filters
                |> Filters.update filter toggle
                |> SetDefaultFilters
                |> wrap

        resolvedFilters =
            Filters.resolveDefaults filters

        viewFilter filter =
            let
                value =
                    Filters.value filter resolvedFilters

                { title, description } =
                    Filters.describe filter
            in
            FilterChip.chip title
                |> FilterChip.button (value |> not |> setFilter filter |> Just)
                |> FilterChip.selected value
                |> FilterChip.attrs [ HtmlA.title description ]
                |> FilterChip.view

        selectTheme =
            Theme.fromString
                >> Maybe.withDefault Theme.Auto
                >> SetTheme
                >> wrap
                |> Just

        themeSelect =
            Theme.selector selectTheme (Just settings.theme.value)

        selectLayout =
            Layout.fromString
                >> Maybe.withDefault Layout.Auto
                >> SetLayout
                >> wrap
                |> Just

        layoutSelect =
            Layout.selector selectLayout (Just settings.layout.value)
    in
    [ Dialog.dialog (False |> SetVisibility |> wrap)
        [ Html.div [ HtmlA.class "theme" ] [ themeSelect ]
        , Html.div [ HtmlA.class "layout" ] [ layoutSelect ]
        , Html.div [ HtmlA.class "default-filters" ]
            [ Html.h3 [] [ Html.text "Default Filters" ]
            , Html.p [] [ Html.text "On games you haven't set them on, what will the filters will be. Each game's filters will be remembered separately on top of this." ]
            , Filters.allFilters |> List.map viewFilter |> Chips.set []
            ]
        ]
        [ Button.text "Close"
            |> Button.icon [ Icon.times |> Icon.view ]
            |> Button.button (False |> SetVisibility |> wrap |> Just)
            |> Button.view
        ]
        settings.visible
        |> Dialog.headline [ Html.text "Settings" ]
        |> Dialog.attrs [ HtmlA.id "client-settings" ]
        |> Dialog.view
    ]


apply : Change -> Model -> Model
apply change model =
    case change of
        DefaultFiltersItem item ->
            { model | defaultFilters = item }

        ThemeItem item ->
            { model | theme = item }

        LayoutItem item ->
            { model | layout = item }
