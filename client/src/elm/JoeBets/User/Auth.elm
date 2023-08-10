module JoeBets.User.Auth exposing
    ( init
    , load
    , logInButton
    , logInOutButton
    , update
    , updateLocalUser
    , viewError
    )

import Browser.Events as Browser
import Browser.Navigation as Navigation
import FontAwesome as Icon
import FontAwesome.Attributes as Icon
import FontAwesome.Brands as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Events as HtmlE
import Http
import JoeBets.Api as Api
import JoeBets.Page.Model as Page exposing (Page)
import JoeBets.Page.Problem.Model as Problem
import JoeBets.Route as Route exposing (Route)
import JoeBets.Store.Session as Session
import JoeBets.Store.Session.Model as Session
import JoeBets.User.Auth.Model exposing (..)
import JoeBets.User.Auth.Route exposing (..)
import JoeBets.User.Model as User exposing (User)
import JoeBets.User.Notifications as Notifications
import JoeBets.User.Notifications.Model as Notifications
import Json.Decode as JsonD
import Util.Http.StatusCodes as Http
import Util.Maybe as Maybe
import Util.RemoteData as RemoteData


type alias Parent a =
    { a
        | auth : Model
        , navigationKey : Navigation.Key
        , origin : String
        , route : Route
        , notifications : Notifications.Model
        , visibility : Browser.Visibility
        , page : Page
        , problem : Problem.Model
    }


type InitiatedBy
    = User
    | System


handleLogInResponse : (Msg -> msg) -> InitiatedBy -> Result Error RedirectOrLoggedIn -> msg
handleLogInResponse wrap redirect result =
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


init : (Msg -> msg) -> String -> Route -> ( Model, Cmd msg )
init wrap origin route =
    let
        cmd =
            case route of
                Route.Auth (Just _) ->
                    Cmd.none

                _ ->
                    Api.post origin
                        { path = Api.Auth Api.Login
                        , body = Http.emptyBody
                        , expect =
                            expectJsonOrUnauthorised
                                (handleLogInResponse wrap System)
                                redirectOrLoggedInDecoder
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


load : (Msg -> msg) -> Maybe CodeAndState -> Parent a -> ( Parent a, Cmd msg )
load wrap maybeCodeAndState ({ auth } as model) =
    case maybeCodeAndState of
        Nothing ->
            ( model, Cmd.none )

        Just codeAndState ->
            ( { model | auth = { auth | inProgress = Just LoggingIn } }
            , Api.post model.origin
                { path = Api.Auth Api.Login
                , body = codeAndState |> encodeCodeAndState |> Http.jsonBody
                , expect =
                    expectJsonOrUnauthorised
                        (handleLogInResponse wrap User)
                        redirectOrLoggedInDecoder
                }
            )


update : (Msg -> msg) -> msg -> (Notifications.Msg -> msg) -> Msg -> Parent a -> ( Parent a, Cmd msg )
update wrap noOp wrapNotifications msg ({ route, auth, page, problem } as model) =
    case msg of
        Login progress ->
            case progress of
                Start ->
                    ( { model | auth = { auth | inProgress = Just LoggingIn } }
                    , Cmd.batch
                        [ setLoginRedirect route
                        , Api.post model.origin
                            { path = Api.Auth Api.Login
                            , body = Http.emptyBody
                            , expect =
                                expectJsonOrUnauthorised
                                    (handleLogInResponse wrap User)
                                    redirectOrLoggedInDecoder
                            }
                        ]
                    )

                FinishNotLoggedIn ->
                    ( { model
                        | auth =
                            { auth
                                | inProgress = Nothing
                                , localUser = Nothing
                            }
                      }
                    , deleteLoginRedirect
                    )

                Continue { redirect } ->
                    ( model, Navigation.load redirect )

                Failed error ->
                    ( { model
                        | auth =
                            { auth
                                | inProgress = Nothing
                                , error = Just error
                                , localUser = Nothing
                            }
                      }
                    , deleteLoginRedirect
                    )

        SetLocalUser loggedIn ->
            let
                redirectCmd =
                    case page of
                        Page.Problem ->
                            case problem of
                                Problem.MustBeLoggedIn { path } ->
                                    Navigation.pushUrl model.navigationKey path

                                _ ->
                                    Cmd.none

                        _ ->
                            Cmd.none

                newModel =
                    { model
                        | auth =
                            { auth
                                | inProgress = Nothing
                                , localUser = Just loggedIn.user
                                , error = Nothing
                            }
                    }

                ( withNotifications, notificationsCmd ) =
                    Notifications.update
                        wrapNotifications
                        (loggedIn.notifications |> Ok |> Notifications.Load)
                        newModel
            in
            ( withNotifications
            , Cmd.batch [ redirectCmd, notificationsCmd, getLoginRedirect ]
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
            ( { model
                | auth =
                    { auth
                        | inProgress = Nothing
                        , localUser = Nothing
                    }
              }
            , Api.post model.origin
                { path = Api.Auth Api.Logout
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
                    if auth.inProgress == Nothing then
                        ( Icon.discord, Start |> Login |> wrap |> HtmlE.onClick, "Log in" )

                    else
                        ( Icon.spinner |> Icon.styled [ Icon.spinPulse ], HtmlA.disabled True, "Log in" )

                Just _ ->
                    if auth.inProgress == Nothing then
                        ( Icon.signOutAlt, Logout |> wrap |> HtmlE.onClick, "Log out" )

                    else
                        ( Icon.spinner |> Icon.styled [ Icon.spinPulse ], HtmlA.disabled True, "Log out" )
    in
    Html.button [ action ] [ Icon.view icon, Html.text text ]


logInButton : (Msg -> msg) -> Model -> Html msg -> Html msg
logInButton wrap auth content =
    let
        button =
            case auth.localUser of
                Nothing ->
                    Html.button
                        [ HtmlA.class "log-in"
                        , Start |> Login |> wrap |> HtmlE.onClick
                        ]
                        [ content ]
                        |> Just

                Just _ ->
                    Nothing
    in
    button
        |> Maybe.andThen (Maybe.when (auth.inProgress == Nothing))
        |> Maybe.withDefault content


viewError : { a | auth : Model } -> List (Html msg)
viewError { auth } =
    case auth.error of
        Just Unauthorized ->
            [ Html.div [ HtmlA.class "error" ] [ Html.text "Unauthorized" ] ]

        Just (HttpError error) ->
            [ Html.div [ HtmlA.class "error" ] [ error |> RemoteData.errorToString |> Html.text ] ]

        Nothing ->
            []


expectJsonOrUnauthorised : (Result Error a -> msg) -> JsonD.Decoder a -> Http.Expect msg
expectJsonOrUnauthorised wrapResult decoder =
    let
        handleResponse response =
            case response of
                Http.BadUrl_ url ->
                    url |> Http.BadUrl |> HttpError |> Err

                Http.Timeout_ ->
                    Http.Timeout |> HttpError |> Err

                Http.NetworkError_ ->
                    Http.NetworkError |> HttpError |> Err

                Http.BadStatus_ { statusCode } _ ->
                    if statusCode == Http.unauthorized then
                        Unauthorized |> Err

                    else
                        statusCode |> Http.BadStatus |> HttpError |> Err

                Http.GoodStatus_ _ body ->
                    case JsonD.decodeString decoder body of
                        Ok value ->
                            Ok value

                        Err err ->
                            err |> JsonD.errorToString |> Http.BadBody |> HttpError |> Err
    in
    Http.expectStringResponse wrapResult handleResponse


updateLocalUser : (User.Id -> User -> User) -> { parent | auth : Model } -> { parent | auth : Model }
updateLocalUser updateUser ({ auth } as model) =
    let
        modifyUserWithId ({ id, user } as userWithId) =
            { userWithId | user = updateUser id user }
    in
    { model | auth = { auth | localUser = auth.localUser |> Maybe.map modifyUserWithId } }
