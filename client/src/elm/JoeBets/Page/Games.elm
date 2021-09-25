module JoeBets.Page.Games exposing
    ( init
    , load
    , update
    , view
    )

import AssocList
import EverySet
import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html
import Html.Attributes as HtmlA
import Http
import JoeBets.Api as Api
import JoeBets.Game as Game
import JoeBets.Page exposing (Page)
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Page.Edit.Model as Edit
import JoeBets.Page.Games.Model exposing (..)
import JoeBets.Route as Route
import JoeBets.User.Auth.Model as Auth
import Material.Switch as Switch
import Time.Model as Time
import Util.RemoteData as RemoteData


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
    { games = RemoteData.Missing
    , favouritesOnly = False
    }


load : (Msg -> msg) -> Parent a -> ( Parent a, Cmd msg )
load wrap model =
    ( model
    , Api.get model.origin
        { path = Api.Games
        , expect = Http.expectJson (Load >> wrap) gamesDecoder
        }
    )


update : Msg -> Parent a -> ( Parent a, Cmd msg )
update msg ({ games } as model) =
    case msg of
        Load response ->
            ( { model | games = { games | games = RemoteData.load response } }, Cmd.none )

        SetFavouritesOnly favouritesOnly ->
            ( { model | games = { games | favouritesOnly = favouritesOnly } }, Cmd.none )


view : (Msg -> msg) -> (Bets.Msg -> msg) -> Parent a -> Page msg
view wrap wrapBets { auth, time, games, bets } =
    let
        viewGame ( id, game ) =
            if not games.favouritesOnly || EverySet.member id bets.favourites.value then
                Html.li [] [ Game.view wrapBets bets time auth.localUser id game Nothing ] |> Just

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
                    if Auth.isAdmin auth.localUser then
                        [ Route.a (Edit.Game Nothing |> Route.Edit)
                            []
                            [ Icon.plus |> Icon.present |> Icon.view, Html.text " Add Game" ]
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
            :: Html.div []
                [ Switch.view (Html.text "Favourite Games Only")
                    games.favouritesOnly
                    (SetFavouritesOnly >> wrap |> Just)
                ]
            :: RemoteData.view body games.games
    }
