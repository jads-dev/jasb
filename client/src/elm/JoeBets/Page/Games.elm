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
import Html
import Html.Attributes as HtmlA
import JoeBets.Api as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.Path as Api
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
import Material.Switch as Switch
import Time.Model as Time


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
    , favouritesOnly = False
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

        SetFavouritesOnly favouritesOnly ->
            ( { model | games = { games | favouritesOnly = favouritesOnly } }
            , Cmd.none
            )


view : Parent a -> Page Global.Msg
view { auth, time, games, bets } =
    let
        viewGame ( id, game ) =
            if not games.favouritesOnly || EverySet.member id bets.favourites.value then
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
            Html.div [ HtmlA.class class ]
                [ Html.h3 [] [ Html.text title ]
                , subset |> AssocList.toList |> List.filterMap viewGame |> Html.ol []
                ]

        body { future, current, finished } =
            let
                admin =
                    if Auth.canManageGames auth.localUser then
                        [ Button.text "Add Game"
                            |> Button.icon (Icon.plus |> Icon.view)
                            |> Material.buttonLink
                                Global.ChangeUrl
                                (Edit.Game Nothing |> Route.Edit)
                            |> Button.view
                        ]

                    else
                        []
            in
            [ Html.div [ HtmlA.class "games" ]
                [ viewSubset "current" "Current" current
                , viewSubset "future" "Future" future
                , viewSubset "finished" "Finished" finished
                ]
            , Html.ul [ HtmlA.class "final-actions" ] (admin |> List.map (List.singleton >> Html.li []))
            ]
    in
    { title = "Games"
    , id = "games"
    , body =
        Html.h2 [] [ Html.text "Games" ]
            :: Html.label [ HtmlA.class "switch" ]
                [ Html.span [] [ Html.text "Favourite Games Only" ]
                , Switch.switch
                    (SetFavouritesOnly >> wrap |> Just)
                    games.favouritesOnly
                    |> Switch.view
                ]
            :: Api.viewData Api.viewOrError body games.games
    }
