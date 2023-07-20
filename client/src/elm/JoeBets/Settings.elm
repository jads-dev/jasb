module JoeBets.Settings exposing
    ( init
    , update
    , view
    )

import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Events as HtmlE
import JoeBets.Layout as Layout
import JoeBets.Page.Bets.Filters as Filters
import JoeBets.Settings.Model exposing (..)
import JoeBets.Store as Store
import JoeBets.Store.Codecs as Codecs
import JoeBets.Store.Item as Item
import JoeBets.Store.KeyedItem as Store exposing (KeyedItem)
import JoeBets.Theme as Theme
import Material.Attributes as Material
import Material.IconButton as IconButton
import Material.Select as Select
import Material.Switch as Switch
import Util.Maybe as Maybe


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

            viewFilter title description value filter =
                Html.li [ HtmlA.title description ]
                    [ Switch.view (Html.text title) value (setFilter filter |> Just) ]

            themeSelectModel =
                { label = "Theme"
                , idToString = Theme.toString
                , idFromString = Theme.fromString
                , selected = Just settings.theme.value
                , wrap = Maybe.withDefault Theme.Auto >> SetTheme >> wrap
                , disabled = False
                , fullWidth = True
                , attrs = [ Material.outlined ]
                }

            layoutSelectModel =
                { label = "Layout"
                , idToString = Layout.toString
                , idFromString = Layout.fromString
                , selected = Just settings.layout.value
                , wrap = Maybe.withDefault Layout.Auto >> SetLayout >> wrap
                , disabled = False
                , fullWidth = True
                , attrs = [ Material.outlined ]
                }
        in
        [ Html.div [ HtmlA.id "client-settings" ]
            [ Html.div [ HtmlA.class "background", False |> SetVisibility |> wrap |> HtmlE.onClick ] []
            , Html.div [ HtmlA.class "foreground" ]
                [ Html.div []
                    [ Html.div [ HtmlA.class "title" ]
                        [ Html.h2 [] [ Html.text "Settings" ]
                        , IconButton.view (Icon.times |> Icon.view)
                            "Close"
                            (False |> SetVisibility |> wrap |> Just)
                        ]
                    , Html.div [ HtmlA.class "default-filters" ]
                        [ Html.h3 [] [ Html.text "Default Filters" ]
                        , Html.p [] [ Html.text "On games you haven't set them on, what will the filters will be. Each game's filters will be remembered separately on top of this." ]
                        , Html.ul []
                            [ viewFilter "Open" "Bets you can still bet on." resolvedFilters.voting Filters.Voting
                            , viewFilter "Locked" "Bets that are ongoing but you can't bet on." resolvedFilters.locked Filters.Locked
                            , viewFilter "Finished" "Bets that are resolved." resolvedFilters.complete Filters.Complete
                            , viewFilter "Cancelled" "Bets that have been cancelled." resolvedFilters.cancelled Filters.Cancelled
                            , viewFilter "Have Bet" "Bets that you have a stake in." resolvedFilters.hasBet Filters.HasBet
                            , viewFilter "Spoilers" "Bets that give serious spoilers for the game." resolvedFilters.spoilers Filters.Spoilers
                            ]
                        ]
                    , Html.div [ HtmlA.class "theme" ]
                        [ Html.h3 [] [ Html.text "Theme" ]
                        , Html.p [] [ Html.text "What theme to use for the site." ]
                        , Theme.all |> List.map Theme.selectItem |> Select.view themeSelectModel
                        ]
                    , Html.div [ HtmlA.class "layout" ]
                        [ Html.h3 [] [ Html.text "Layout" ]
                        , Html.p [] [ Html.text "What layout to use for the site." ]
                        , Layout.all |> List.map Layout.selectItem |> Select.view layoutSelectModel
                        ]
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
