module JoeBets.User.Auth exposing
    ( init
    , load
    , logInOutButton
    , update
    )

import Browser.Events as Browser
import Browser.Navigation as Navigation
import FontAwesome.Attributes as Icon
import FontAwesome.Brands as Icon
import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Events as HtmlE
import Http
import JoeBets.Api as Api
import JoeBets.Route as Route exposing (Route)
import JoeBets.User.Auth.Model as Route exposing (..)
import JoeBets.User.Model as User
import JoeBets.User.Notifications as Notifications


type alias Parent a =
    { a
        | auth : Model
        , navigationKey : Navigation.Key
        , origin : String
        , notifications : Notifications.Model
        , visibility : Browser.Visibility
    }


init : (Msg -> msg) -> msg -> String -> Route -> ( Model, Cmd msg )
init wrap noOp origin route =
    let
        handle result =
            case result of
                Ok continue ->
                    case continue of
                        R _ ->
                            noOp

                        U userWithId ->
                            userWithId |> SetLocalUser False |> wrap

                Err _ ->
                    noOp

        cmd =
            case route of
                Route.Auth (Just _) ->
                    Cmd.none

                _ ->
                    Api.post origin
                        { path = [ "auth", "login" ]
                        , body = Http.emptyBody
                        , expect = Http.expectJson handle redirectOrUserDecoder
                        }
    in
    ( { trying = False, localUser = Nothing }, cmd )


load : (Msg -> msg) -> Maybe CodeAndState -> Parent a -> ( Parent a, Cmd msg )
load wrap maybeCodeAndState ({ auth } as model) =
    case maybeCodeAndState of
        Nothing ->
            ( model, Cmd.none )

        Just codeAndState ->
            if not auth.trying then
                let
                    handle result =
                        case result of
                            Ok userWithId ->
                                userWithId |> SetLocalUser True |> wrap

                            Err _ ->
                                Failed |> Login |> wrap
                in
                ( { model | auth = { auth | trying = True } }
                , Api.post model.origin
                    { path = [ "auth", "login" ]
                    , body = codeAndState |> encodeCodeAndState |> Http.jsonBody
                    , expect = Http.expectJson handle User.withIdDecoder
                    }
                )

            else
                ( model, Cmd.none )


update : (Msg -> msg) -> msg -> (Notifications.Msg -> msg) -> Msg -> Parent a -> ( Parent a, Cmd msg )
update wrap noOp wrapNotifications msg ({ auth } as model) =
    case msg of
        Login progress ->
            case progress of
                Start ->
                    let
                        handle result =
                            case result of
                                Ok continue ->
                                    case continue of
                                        R redirect ->
                                            redirect |> Continue |> Login |> wrap

                                        U userWithId ->
                                            userWithId |> SetLocalUser True |> wrap

                                Err _ ->
                                    Failed |> Login |> wrap
                    in
                    ( { model | auth = { auth | trying = True } }
                    , Api.post model.origin
                        { path = [ "auth", "login" ]
                        , body = Http.emptyBody
                        , expect = Http.expectJson handle redirectOrUserDecoder
                        }
                    )

                Continue { redirect } ->
                    ( model, Navigation.load redirect )

                Failed ->
                    ( { model | auth = { auth | trying = False } }, Cmd.none )

        SetLocalUser redirect ({ id, user } as userData) ->
            let
                redirectCmd =
                    if redirect then
                        id
                            |> Just
                            |> Route.User
                            |> Route.toUrl
                            |> Navigation.pushUrl model.navigationKey

                    else
                        Cmd.none

                newModel =
                    { model | auth = { auth | trying = False, localUser = Just userData } }

                getNotifications =
                    Notifications.load wrapNotifications newModel
            in
            ( newModel, Cmd.batch [ redirectCmd, getNotifications ] )

        Logout ->
            ( { model | auth = { auth | trying = False, localUser = Nothing } }
            , Api.post model.origin
                { path = [ "auth", "logout" ]
                , body = Http.emptyBody
                , expect = Http.expectWhatever (always noOp)
                }
            )


logInOutButton : (Msg -> msg) -> Parent a -> Html msg
logInOutButton wrap { auth } =
    let
        ( icon, action, text ) =
            case auth.localUser of
                Nothing ->
                    if not auth.trying then
                        ( Icon.discord |> Icon.present, Start |> Login |> wrap |> HtmlE.onClick, "Log in" )

                    else
                        ( Icon.spinner |> Icon.present |> Icon.styled [ Icon.pulse ], HtmlA.disabled True, "Log in" )

                Just _ ->
                    if not auth.trying then
                        ( Icon.signOutAlt |> Icon.present, Logout |> wrap |> HtmlE.onClick, "Log out" )

                    else
                        ( Icon.spinner |> Icon.present |> Icon.styled [ Icon.pulse ], HtmlA.disabled True, "Log out" )
    in
    Html.button [ action ] [ Icon.view icon, Html.text text ]
