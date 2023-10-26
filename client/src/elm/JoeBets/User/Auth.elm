module JoeBets.User.Auth exposing
    ( init
    , load
    , update
    , updateLocalUser
    , view
    , viewError
    )

import Browser.Events as Browser
import Browser.Navigation as Navigation
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Api as Api
import JoeBets.Api.Error as Api
import JoeBets.Api.Model as Api
import JoeBets.Api.Path as Api
import JoeBets.Messages as Global
import JoeBets.Page exposing (Page)
import JoeBets.Page.Gacha as Gacha
import JoeBets.Page.Gacha.Collection.Model as Collection
import JoeBets.Page.Gacha.Forge.Model as Forge
import JoeBets.Page.Gacha.Model as Gacha
import JoeBets.Page.Problem as Problem
import JoeBets.Page.Problem.Model as Problem
import JoeBets.Route as Route exposing (Route)
import JoeBets.Store.Session as Session
import JoeBets.Store.Session.Model as Session
import JoeBets.User.Auth.Model exposing (..)
import JoeBets.User.Auth.Route exposing (..)
import JoeBets.User.Model as User exposing (User)
import JoeBets.User.Notifications as Notifications
import JoeBets.User.Notifications.Model as Notifications
import Json.Encode as JsonE
import Material.IconButton as IconButton
import Material.Progress as Progress
import Time.Model as Time


wrap : Msg -> Global.Msg
wrap =
    Global.AuthMsg


type alias Parent a =
    { a
        | auth : Model
        , navigationKey : Navigation.Key
        , origin : String
        , time : Time.Context
        , route : Route
        , notifications : Notifications.Model
        , visibility : Browser.Visibility
        , problem : Problem.Model
        , gacha : Gacha.Model
        , collection : Collection.Model
        , forge : Forge.Model
    }


type InitiatedBy
    = User
    | System


handleLogInResponse : InitiatedBy -> Api.Response RedirectOrLoggedIn -> Global.Msg
handleLogInResponse redirect result =
    case result of
        Ok continue ->
            case continue of
                R target ->
                    case redirect of
                        User ->
                            target |> Continue |> Login |> wrap

                        System ->
                            FinishNotLoggedIn |> Login |> wrap

                L loggedIn ->
                    loggedIn |> SetLocalUser |> wrap

        Err error ->
            error |> Failed |> Login |> wrap


init : String -> Route -> ( Model, Cmd Global.Msg )
init origin route =
    let
        cmd =
            case route of
                Route.Auth (Just _) ->
                    Cmd.none

                _ ->
                    Api.post origin
                        { path = Api.Auth Api.Login
                        , body = JsonE.object []
                        , wrap = handleLogInResponse System
                        , decoder = redirectOrLoggedInDecoder
                        }
    in
    ( { inProgress = Just LoggingIn
      , error = Nothing
      , localUser = Nothing
      }
    , cmd
    )


setLoginRedirect : Route -> Cmd msg
setLoginRedirect =
    Just >> Session.LoginRedirectValue >> Session.set


deleteLoginRedirect : Cmd msg
deleteLoginRedirect =
    Session.LoginRedirect |> Session.delete


getLoginRedirect : Cmd msg
getLoginRedirect =
    Session.LoginRedirect |> Session.get


load : Maybe CodeAndState -> Parent a -> ( Parent a, Cmd Global.Msg )
load maybeCodeAndState ({ auth } as model) =
    case maybeCodeAndState of
        Nothing ->
            ( model, Cmd.none )

        Just codeAndState ->
            ( { model | auth = { auth | inProgress = Just LoggingIn } }
            , Api.post model.origin
                { path = Api.Auth Api.Login
                , body = codeAndState |> encodeCodeAndState
                , wrap = handleLogInResponse User
                , decoder = redirectOrLoggedInDecoder
                }
            )


onAuthChange : Route -> Parent a -> ( Parent a, Cmd Global.Msg )
onAuthChange route =
    case route of
        Route.Problem _ ->
            Problem.onAuthChange

        Route.Gacha gachaRoute ->
            Gacha.onAuthChange gachaRoute

        _ ->
            \m -> ( m, Cmd.none )


update : Msg -> Parent a -> ( Parent a, Cmd Global.Msg )
update msg ({ route, auth } as model) =
    case msg of
        Login progress ->
            case progress of
                Start ->
                    ( { model | auth = { auth | inProgress = Just LoggingIn } }
                    , Cmd.batch
                        [ setLoginRedirect route
                        , Api.post model.origin
                            { path = Api.Auth Api.Login
                            , body = JsonE.object []
                            , wrap = handleLogInResponse User
                            , decoder = redirectOrLoggedInDecoder
                            }
                        ]
                    )

                FinishNotLoggedIn ->
                    let
                        newAuth =
                            { auth
                                | inProgress = Nothing
                                , localUser = Nothing
                            }
                    in
                    ( { model | auth = newAuth }
                    , Cmd.batch
                        [ deleteLoginRedirect
                        , Notifications.changeAuthed newAuth
                        ]
                    )

                Continue { redirect } ->
                    ( model, Navigation.load redirect )

                Failed error ->
                    let
                        newAuth =
                            { auth
                                | inProgress = Nothing
                                , error = Just error
                                , localUser = Nothing
                            }
                    in
                    ( { model | auth = newAuth }
                    , Cmd.batch
                        [ deleteLoginRedirect
                        , Notifications.changeAuthed newAuth
                        ]
                    )

        SetLocalUser loggedIn ->
            let
                newAuth =
                    { auth
                        | inProgress = Nothing
                        , localUser = Just loggedIn.user
                        , error = Nothing
                    }

                ( finalModel, onLogInCmd ) =
                    { model | auth = newAuth, notifications = loggedIn.notifications }
                        |> onAuthChange route
            in
            ( finalModel
            , Cmd.batch
                [ onLogInCmd
                , getLoginRedirect
                , Notifications.changeAuthed newAuth
                ]
            )

        RedirectAfterLogin maybeRoute ->
            case maybeRoute of
                Just redirectTo ->
                    ( model
                    , Cmd.batch
                        [ deleteLoginRedirect
                        , Route.pushUrl model.navigationKey redirectTo
                        ]
                    )

                Nothing ->
                    ( model, Cmd.none )

        Logout ->
            let
                newAuth =
                    { auth
                        | inProgress = Nothing
                        , localUser = Nothing
                    }

                logoutRequest =
                    Api.post model.origin
                        { path = Api.Auth Api.Logout
                        , body = JsonE.object []
                        , wrap = \_ -> "Logout result" |> Global.NoOp
                        , decoder = User.idDecoder
                        }

                ( finalModel, authChangeCmd ) =
                    onAuthChange route { model | auth = newAuth }
            in
            ( finalModel
            , Cmd.batch
                [ logoutRequest
                , Notifications.changeAuthed newAuth
                , authChangeCmd
                ]
            )

        DismissError ->
            ( { model | auth = { auth | error = Nothing } }
            , Cmd.none
            )


view : Maybe CodeAndState -> { a | auth : Model } -> Page Global.Msg
view _ _ =
    { title = "Logging In..."
    , id = "auth"
    , body =
        [ Progress.linear
            |> Progress.attrs [ HtmlA.class "progress" ]
            |> Progress.view
        ]
    }


viewError : { a | auth : Model } -> List (Html Global.Msg)
viewError { auth } =
    case auth.error of
        Just error ->
            [ Html.div [ HtmlA.class "auth-error" ]
                [ IconButton.icon (Icon.view Icon.close) "Dismiss"
                    |> IconButton.button (DismissError |> wrap |> Just)
                    |> IconButton.view
                , Html.h3 [] [ Html.text "Problem logging in:" ]
                , Api.viewError error
                ]
            ]

        Nothing ->
            []


updateLocalUser : (User.Id -> User -> User) -> { parent | auth : Model } -> { parent | auth : Model }
updateLocalUser updateUser ({ auth } as model) =
    let
        modifyUserWithId ({ id, user } as userWithId) =
            { userWithId | user = updateUser id user }
    in
    { model | auth = { auth | localUser = auth.localUser |> Maybe.map modifyUserWithId } }
