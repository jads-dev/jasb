module JoeBets.Settings exposing
    ( init
    , update
    , view
    )

import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Layout as Layout
import JoeBets.Overlay as Overlay
import JoeBets.Page.Bets.Filters as Filters
import JoeBets.Settings.Model exposing (..)
import JoeBets.Store as Store
import JoeBets.Store.Codecs as Codecs
import JoeBets.Store.Item as Item
import JoeBets.Store.KeyedItem as Store exposing (KeyedItem)
import JoeBets.Theme as Theme
import Material.Chips as Chips
import Material.Chips.Filter as FilterChip
import Material.IconButton as IconButton


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
    if settings.visible then
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
        [ Overlay.view (False |> SetVisibility |> wrap)
            [ Html.div [ HtmlA.id "client-settings" ]
                [ Html.div [ HtmlA.class "title" ]
                    [ Html.h2 [] [ Html.text "Settings" ]
                    , IconButton.icon (Icon.times |> Icon.view) "Close"
                        |> IconButton.button (False |> SetVisibility |> wrap |> Just)
                        |> IconButton.view
                    ]
                , Html.div [ HtmlA.class "theme" ] [ themeSelect ]
                , Html.div [ HtmlA.class "layout" ] [ layoutSelect ]
                , Html.div [ HtmlA.class "default-filters" ]
                    [ Html.h3 [] [ Html.text "Default Filters" ]
                    , Html.p [] [ Html.text "On games you haven't set them on, what will the filters will be. Each game's filters will be remembered separately on top of this." ]
                    , Filters.allFilters |> List.map viewFilter |> Chips.set []
                    ]
                ]
            ]
        ]

    else
        []


apply : Change -> Model -> Model
apply change model =
    case change of
        DefaultFiltersItem item ->
            { model | defaultFilters = item }

        ThemeItem item ->
            { model | theme = item }

        LayoutItem item ->
            { model | layout = item }
