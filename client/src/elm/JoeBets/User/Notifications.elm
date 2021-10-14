module JoeBets.User.Notifications exposing
    ( Msg(..)
    , init
    , load
    , subscriptions
    , update
    , view
    )

import Browser.Events as Browser
import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Http
import JoeBets.Api as Api
import JoeBets.Coins as Coins
import JoeBets.Route as Route
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Notifications.Model exposing (..)
import Json.Decode as JsonD
import Material.IconButton as IconButton
import Time


type alias Parent a =
    { a
        | notifications : Model
        , origin : String
        , auth : Auth.Model
        , visibility : Browser.Visibility
    }


type Msg
    = Request
    | Load (Result Http.Error Model)
    | SetRead Int
    | NoOp


init : Model
init =
    []


load : (Msg -> msg) -> Parent a -> Cmd msg
load wrap model =
    case model.auth.localUser of
        Just { id } ->
            Api.get model.origin
                { path = Nothing |> Api.Notifications |> Api.User id
                , expect = Http.expectJson (Load >> wrap) (JsonD.list decoder)
                }

        Nothing ->
            Cmd.none


update : (Msg -> msg) -> Msg -> Parent a -> ( Parent a, Cmd msg )
update wrap msg model =
    case msg of
        Request ->
            ( model, load wrap model )

        Load result ->
            case result of
                Ok notifications ->
                    ( { model | notifications = notifications }, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        SetRead notificationId ->
            case model.auth.localUser of
                Just { id } ->
                    ( { model | notifications = model.notifications |> List.filter (getId >> (/=) notificationId) }
                    , Api.post model.origin
                        { path = notificationId |> Just |> Api.Notifications |> Api.User id
                        , body = Http.emptyBody
                        , expect = Http.expectWhatever (NoOp |> wrap |> always)
                        }
                    )

                Nothing ->
                    ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


subscriptions : (Msg -> msg) -> Parent a -> Sub msg
subscriptions wrap { auth, visibility } =
    case visibility of
        Browser.Visible ->
            case auth.localUser of
                Just _ ->
                    Request |> wrap |> always |> Time.every 120000

                Nothing ->
                    Sub.none

        Browser.Hidden ->
            Sub.none


view : (Msg -> msg) -> Parent a -> Html msg
view wrap { notifications } =
    let
        viewReference reference =
            Route.a (Route.Bet reference.gameId reference.betId)
                []
                [ Html.text "your bet on “"
                , Html.text reference.optionName
                , Html.text "” in the “"
                , Html.text reference.betName
                , Html.text "” bet on “"
                , Html.text reference.gameName
                , Html.text "”"
                ]

        viewNotification notification =
            let
                content =
                    case notification of
                        Gift { reason, amount } ->
                            case reason of
                                AccountCreated ->
                                    [ Html.text "You have been gifted with "
                                    , Coins.view amount
                                    , Html.text " as a new user."
                                    ]

                        Refund refund ->
                            let
                                reason =
                                    case refund.reason of
                                        BetCancelled ->
                                            Html.text "the bet was cancelled"

                                        OptionRemoved ->
                                            Html.text "the option was removed"
                            in
                            [ Html.text "You have been refunded for "
                            , viewReference refund
                            , Html.text " because "
                            , reason
                            , Html.text ". "
                            , Coins.view refund.amount
                            , Html.text " has been returned to your balance."
                            ]

                        BetFinish betFinished ->
                            let
                                ( result, extra ) =
                                    case betFinished.result of
                                        Win ->
                                            ( Html.text "won"
                                            , [ Html.text " Your winnings of "
                                              , Coins.view betFinished.amount
                                              , Html.text " have been paid into your balance."
                                              ]
                                            )

                                        Loss ->
                                            ( Html.text "lost", [] )
                            in
                            [ Html.text "You have "
                            , result
                            , Html.text " "
                            , viewReference betFinished
                            , Html.text "."
                            ]
                                ++ extra

                        BetRevert betReverted ->
                            let
                                description =
                                    case betReverted.reverted of
                                        Cancelled ->
                                            Html.text "cancelled"

                                        Complete ->
                                            Html.text "completed"
                            in
                            [ Html.text "Previously "
                            , viewReference betReverted
                            , Html.text " was "
                            , description
                            , Html.text ", this has been reverted."
                            ]
            in
            Html.li []
                [ Html.p [] content
                , IconButton.view (Icon.envelopeOpen |> Icon.present |> Icon.view)
                    "Mark As Read"
                    (notification |> getId |> SetRead |> wrap |> Just)
                ]
    in
    Html.div [ HtmlA.id "notifications", HtmlA.classList [ ( "hidden", notifications |> List.isEmpty ) ] ]
        [ notifications |> List.map viewNotification |> Html.ul []
        ]
