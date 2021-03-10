module JoeBets.Page.Games exposing
    ( init
    , load
    , update
    , view
    )

import AssocList
import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Http
import JoeBets.Api as Api
import JoeBets.Game as Game
import JoeBets.Page exposing (Page)
import JoeBets.Page.Edit.Model as Edit
import JoeBets.Page.Games.Model exposing (..)
import JoeBets.Route as Route
import JoeBets.User.Auth.Model as Auth
import Time
import Util.RemoteData as RemoteData


type alias Parent a =
    { a
        | games : Model
        , origin : String
        , zone : Time.Zone
        , time : Time.Posix
        , auth : Auth.Model
    }


init : Model
init =
    RemoteData.Missing


load : (Msg -> msg) -> Parent a -> ( Parent a, Cmd msg )
load wrap ({ games } as model) =
    ( model
    , Api.get model.origin
        { path = [ "game" ]
        , expect = Http.expectJson (Load >> wrap) gamesDecoder
        }
    )


update : Msg -> Parent a -> ( Parent a, Cmd msg )
update msg ({ games } as model) =
    case msg of
        Load response ->
            ( { model | games = RemoteData.load response }, Cmd.none )


view : (Msg -> msg) -> Parent a -> Page msg
view wrap { auth, zone, time, games } =
    let
        viewGame ( id, game ) =
            Html.li [] [ Route.a (Route.Bets id Nothing) [] [ Game.view zone time auth.localUser id game ] ]

        viewSubset class title subset =
            Html.div [ HtmlA.class class ]
                [ Html.h3 [] [ Html.text title ]
                , subset |> AssocList.toList |> List.map viewGame |> Html.ol []
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
            , Html.div [ HtmlA.class "admin" ] admin
            ]
    in
    { title = "Games"
    , id = "games"
    , body = Html.h2 [] [ Html.text "Games" ] :: RemoteData.view body games
    }
