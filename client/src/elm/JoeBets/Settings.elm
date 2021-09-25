module JoeBets.Settings exposing
    ( init
    , update
    , view
    )

import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Events as HtmlE
import JoeBets.Page.Bets.Filters as Filters
import JoeBets.Settings.Model exposing (..)
import JoeBets.Store as Store
import JoeBets.Store.Codecs as Codecs
import JoeBets.Store.Item as Item
import JoeBets.Store.KeyedItem as Store exposing (KeyedItem)
import Material.Switch as Switch


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
            }
    in
    storeData |> List.filterMap fromItem |> List.foldl apply model


update : Msg -> Parent a -> ( Parent a, Cmd msg )
update msg ({ settings } as model) =
    case msg of
        SetDefaultFilters filters ->
            ( model, Store.set Codecs.defaultFilters (Just settings.defaultFilters) filters )

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
        in
        [ Html.div [ HtmlA.id "client-settings" ]
            [ Html.div [ HtmlA.class "background", False |> SetVisibility |> wrap |> HtmlE.onClick ] []
            , Html.div [ HtmlA.class "foreground" ]
                [ Html.div []
                    [ Html.h2 [] [ Html.text "Settings" ]
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
