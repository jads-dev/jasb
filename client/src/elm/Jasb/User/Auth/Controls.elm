module Jasb.User.Auth.Controls exposing (logInButton, mustBeLoggedIn)

import FontAwesome as Icon
import FontAwesome.Brands as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Jasb.Messages as Global
import Jasb.Page.Problem.Model as Problem
import Jasb.Route as Route exposing (Route)
import Jasb.User.Auth.Model exposing (..)
import Material.Chips.Assist as AssistChip
import Util.Maybe as Maybe


type alias Parent a =
    { a
        | problem : Problem.Model
        , route : Route
    }


wrap : Msg -> Global.Msg
wrap =
    Global.AuthMsg


logInButton : Model -> String -> Html Global.Msg
logInButton auth label =
    let
        button =
            case auth.localUser of
                Nothing ->
                    AssistChip.chip label
                        |> AssistChip.icon [ Icon.discord |> Icon.view ]
                        |> AssistChip.button (Start |> Login |> wrap |> Just)
                        |> AssistChip.attrs [ HtmlA.class "log-in" ]
                        |> AssistChip.view
                        |> Just

                Just _ ->
                    Nothing
    in
    button
        |> Maybe.andThen (Maybe.when (auth.inProgress == Nothing))
        |> Maybe.withDefault (Html.text label)


mustBeLoggedIn : Route -> Parent a -> Parent a
mustBeLoggedIn route model =
    let
        path =
            route |> Route.toUrl
    in
    { model
        | problem = Problem.MustBeLoggedIn { path = path }
        , route = Route.Problem path
    }
