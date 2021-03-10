module JoeBets.User.Notifications exposing
    ( Model
    , Msg(..)
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
import JoeBets.Route as Route
import JoeBets.User as User
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Model as User
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


type alias Model =
    List Notification


type Msg
    = Request
    | Load (Result Http.Error Model)
    | Clear
    | NoOp


init : Model
init =
    []


load : (Msg -> msg) -> Parent a -> Cmd msg
load wrap model =
    case model.auth.localUser of
        Just { id } ->
            Api.get model.origin
                { path = [ "user", id |> User.idToString, "notifications" ]
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

        Clear ->
            case model.auth.localUser of
                Just { id } ->
                    ( { model | notifications = init }
                    , Api.delete model.origin
                        { path = [ "user", id |> User.idToString, "notifications" ]
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
                                    , User.viewBalance amount
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
                            , User.viewBalance refund.amount
                            , Html.text " has been returned to your balance."
                            ]

                        BetFinish betFinished ->
                            let
                                ( result, extra ) =
                                    case betFinished.result of
                                        Win ->
                                            ( Html.text "won"
                                            , [ Html.text " Your winnings of "
                                              , User.viewBalance betFinished.amount
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
            in
            Html.li [] content
    in
    Html.div [ HtmlA.id "notifications", HtmlA.classList [ ( "hidden", notifications |> List.isEmpty ) ] ]
        [ IconButton.view (Icon.trash |> Icon.present |> Icon.view) "Clear" (Clear |> wrap |> Just)
        , notifications |> List.map viewNotification |> Html.ul []
        ]
