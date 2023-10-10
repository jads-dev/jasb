module JoeBets.Page.Games exposing
    ( init
    , load
    , update
    , view
    )

import AssocList
import EverySet
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Api as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.Path as Api
import JoeBets.Filtering as Filtering
import JoeBets.Game as Game
import JoeBets.Material as Material
import JoeBets.Messages as Global
import JoeBets.Page exposing (Page)
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Page.Edit.Model as Edit
import JoeBets.Page.Games.Model exposing (..)
import JoeBets.Route as Route
import JoeBets.User.Auth.Model as Auth
import Material.Button as Button
import Material.Chips.Filter as FilterChip
import Time.Model as Time
import Util.EverySet as EverySet


wrap : Msg -> Global.Msg
wrap =
    Global.GamesMsg


type alias Parent a =
    { a
        | games : Model
        , origin : String
        , time : Time.Context
        , auth : Auth.Model
        , bets : Bets.Model
    }


init : Model
init =
    { games = Api.initData
    , filters = defaultFilters
    }


load : Parent a -> ( Parent a, Cmd Global.Msg )
load ({ games } as model) =
    let
        ( gamesData, cmd ) =
            { path = Api.Games
            , wrap = Load >> wrap
            , decoder = gamesDecoder
            }
                |> Api.get model.origin
                |> Api.getData games.games
    in
    ( { model | games = { games | games = gamesData } }, cmd )


update : Msg -> Parent a -> ( Parent a, Cmd Global.Msg )
update msg ({ games } as model) =
    case msg of
        Load response ->
            ( { model | games = { games | games = games.games |> Api.updateData response } }
            , Cmd.none
            )

        ToggleFilter filter ->
            ( { model | games = { games | filters = games.filters |> EverySet.toggle filter } }
            , Cmd.none
            )


viewFilter : Filters -> Filter -> Html Global.Msg
viewFilter filters filter =
    let
        ( label, description ) =
            case filter of
                FavouriteFilter ->
                    ( "Only Favourite Games", "Only show games you have marked as favourites." )

                HaveBetsFilter ->
                    ( "Only With Bets", "Only show games which have bets." )

                FutureFilter ->
                    ( "Future", "Show games that haven't started yet." )

                CurrentFilter ->
                    ( "Current", "Show games that are being played or have a start date." )

                FinishedFilter ->
                    ( "Finished", "Show games that are finished." )
    in
    FilterChip.chip label
        |> FilterChip.button (ToggleFilter filter |> wrap |> Just)
        |> FilterChip.selected (filters |> EverySet.member filter)
        |> FilterChip.attrs [ HtmlA.title description ]
        |> FilterChip.view


view : Parent a -> Page Global.Msg
view { auth, time, games, bets } =
    let
        filter =
            filterBy
                games.filters
                { favouriteGames = bets.favourites.value }

        viewGame (( id, game ) as pair) =
            if filter pair then
                Html.li []
                    [ Game.view
                        Global.ChangeUrl
                        Global.BetsMsg
                        bets
                        time
                        auth.localUser
                        id
                        game
                    ]
                    |> Just

            else
                Nothing

        viewSubset class title subset =
            let
                subsetGames =
                    subset |> AssocList.toList |> List.filterMap viewGame
            in
            if subsetGames |> List.isEmpty |> not then
                ( [ Html.div [ HtmlA.class class ]
                        [ Html.h3 [] [ Html.text title ]
                        , subsetGames |> Html.ol []
                        ]
                  ]
                , List.length subsetGames
                )

            else
                ( [], 0 )

        body { future, current, finished } =
            let
                totalCount =
                    [ future, current, finished ] |> List.map AssocList.size |> List.sum

                admin =
                    if Auth.canManageGames auth.localUser then
                        [ Button.text "Add Game"
                            |> Button.icon [ Icon.plus |> Icon.view ]
                            |> Material.buttonLink
                                Global.ChangeUrl
                                (Edit.Game Nothing |> Route.Edit)
                            |> Button.view
                        ]

                    else
                        []

                ( subsetsGrouped, counts ) =
                    [ viewSubset "current" "Current" current
                    , viewSubset "future" "Future" future
                    , viewSubset "finished" "Finished" finished
                    ]
                        |> List.unzip

                subsets =
                    subsetsGrouped |> List.concat

                shownCount =
                    counts |> List.sum

                subsetsOrEmpty =
                    if subsets |> List.isEmpty |> not then
                        subsets

                    else
                        [ Html.p [ HtmlA.class "empty" ] [ Icon.ghost |> Icon.view, Html.span [] [ Html.text "No matching games." ] ] ]
            in
            [ possibleFilters
                |> List.map (viewFilter games.filters)
                |> Filtering.viewFilters "Games" totalCount shownCount
            , subsetsOrEmpty |> Html.div [ HtmlA.class "games" ]
            , Html.ul [ HtmlA.class "final-actions" ] (admin |> List.map (List.singleton >> Html.li []))
            ]
    in
    { title = "Games"
    , id = "games"
    , body =
        Html.h2 [] [ Html.text "Games" ]
            :: Api.viewData Api.viewOrError body games.games
    }
