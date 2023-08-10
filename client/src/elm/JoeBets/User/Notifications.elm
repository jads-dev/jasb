module JoeBets.User.Notifications exposing
    ( changeAuthed
    , init
    , load
    , subscriptions
    , update
    , view
    )

import Browser.Events as Browser
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Api as Api
import JoeBets.Api.Path as Api
import JoeBets.Coins as Coins
import JoeBets.Gacha.Balance.Rolls as Balance
import JoeBets.Gacha.Balance.Scrap as Balance
import JoeBets.Messages as Global
import JoeBets.Page.Gacha.Collection.Route as Collection
import JoeBets.Route as Route
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Notifications.Model exposing (..)
import JoeBets.WebSocket as WebSocket
import Json.Decode as JsonD
import Json.Encode as JsonE
import Material.IconButton as IconButton
import Util.List as List


wrap : Msg -> Global.Msg
wrap =
    Global.NotificationsMsg


type alias Parent a =
    { a
        | notifications : Model
        , origin : String
        , auth : Auth.Model
        , visibility : Browser.Visibility
    }


init : Model
init =
    []


load : Parent a -> Cmd Global.Msg
load model =
    case model.auth.localUser of
        Just { id } ->
            { path = Nothing |> Api.Notifications |> Api.SpecificUser id
            , wrap = Load >> wrap
            , decoder = JsonD.list decoder
            }
                |> Api.get model.origin

        Nothing ->
            Cmd.none


changeAuthed : Auth.Model -> Cmd msg
changeAuthed { localUser } =
    case localUser of
        Just { id } ->
            Nothing
                |> Api.Notifications
                |> Api.SpecificUser id
                |> WebSocket.connect

        Nothing ->
            WebSocket.disconnect


update : Msg -> Parent a -> ( Parent a, Cmd Global.Msg )
update msg model =
    case msg of
        Request ->
            ( model, load model )

        Load result ->
            case result of
                Ok notifications ->
                    ( { model | notifications = notifications }, Cmd.none )

                Err _ ->
                    -- TODO: Handle Properly
                    ( model, Cmd.none )

        Append result ->
            case result of
                Ok notification ->
                    ( { model | notifications = notification :: model.notifications }
                    , Cmd.none
                    )

                Err _ ->
                    -- TODO: Handle Properly
                    ( model, Cmd.none )

        SetRead notificationId ->
            case model.auth.localUser of
                Just { id } ->
                    ( { model | notifications = model.notifications |> List.filter (getId >> (/=) notificationId) }
                    , { path = notificationId |> Just |> Api.Notifications |> Api.SpecificUser id
                      , body = JsonE.object []
                      , wrap = \_ -> "Set notification read response." |> NoOp |> wrap
                      , decoder = idDecoder
                      }
                        |> Api.post model.origin
                    )

                Nothing ->
                    ( model, Cmd.none )

        NoOp _ ->
            ( model, Cmd.none )


subscriptions : Sub Global.Msg
subscriptions =
    WebSocket.listen decoder (Append >> wrap)


viewGachaAmount : GachaAmount -> List (Html msg)
viewGachaAmount { rolls, scrap } =
    [ rolls |> Maybe.map Balance.viewRolls
    , scrap |> Maybe.map Balance.viewScrap
    ]
        |> List.filterMap identity


view : Parent a -> List (Html Global.Msg)
view { auth, notifications } =
    case auth.localUser of
        Just user ->
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

                                        Bankruptcy ->
                                            [ Html.text "You have been gifted with "
                                            , Coins.view amount
                                            , Html.text " after your bankruptcy, spend wisely."
                                            ]

                                        SpecialGifted special ->
                                            [ Html.text "You have been gifted with "
                                            , Coins.view amount
                                            , Html.text " because "
                                            , Html.text special.reason
                                            , Html.text "."
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
                                            let
                                                gachaPart =
                                                    viewGachaAmount betFinished.gachaAmount
                                            in
                                            case betFinished.result of
                                                Win ->
                                                    ( Html.text "won"
                                                    , [ [ Html.text " Your winnings of " ]
                                                      , (Coins.view betFinished.amount :: gachaPart)
                                                            |> List.intersperse (Html.text ", ")
                                                            |> List.addBeforeLast (Html.text "and ")
                                                      , [ Html.text " have been paid into your balance." ]
                                                      ]
                                                        |> List.concat
                                                    )

                                                Loss ->
                                                    ( Html.text "lost"
                                                    , if List.isEmpty gachaPart then
                                                        []

                                                      else
                                                        [ [ Html.text " You got " ]
                                                        , gachaPart
                                                        , [ Html.text "." ]
                                                        ]
                                                            |> List.concat
                                                    )
                                    in
                                    Html.text "You have "
                                        :: result
                                        :: Html.text " "
                                        :: viewReference betFinished
                                        :: Html.text "."
                                        :: extra

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

                                GachaGift { reason, amount } ->
                                    case reason of
                                        Historic ->
                                            [ [ Html.text "You now have " ]
                                            , viewGachaAmount amount |> List.addBeforeLast (Html.text " and ")
                                            , [ Html.text " you earned from winning and losing bets." ]
                                            ]
                                                |> List.concat

                                        SpecialGachaGifted special ->
                                            [ [ Html.text "You have been gifted with " ]
                                            , viewGachaAmount amount |> List.addBeforeLast (Html.text " and ")
                                            , [ Html.text " because "
                                              , Html.text special.reason
                                              , Html.text "."
                                              ]
                                            ]
                                                |> List.concat

                                GachaGiftCard { reason, banner, card } ->
                                    case reason of
                                        SelfMade ->
                                            [ Html.text "You have been gifted a "
                                            , Html.text "self-made copy of "
                                            , Route.a
                                                (Collection.Card banner card |> Route.CardCollection user.id)
                                                []
                                                [ Html.text "a card" ]
                                            , Html.text " as you were credited on it."
                                            ]

                                        SpecialGachaGiftedCard special ->
                                            [ Html.text "You have been gifted with "
                                            , Route.a
                                                (Collection.Card banner card |> Route.CardCollection user.id)
                                                []
                                                [ Html.text "a card" ]
                                            , Html.text " because "
                                            , Html.text special.reason
                                            , Html.text "."
                                            ]
                    in
                    Html.li []
                        [ Html.p [] content
                        , IconButton.icon (Icon.envelopeOpen |> Icon.view)
                            "Mark As Read"
                            |> IconButton.button (notification |> getId |> SetRead |> wrap |> Just)
                            |> IconButton.view
                        ]
            in
            [ Html.div [ HtmlA.id "notifications", HtmlA.classList [ ( "hidden", notifications |> List.isEmpty ) ] ]
                [ notifications |> List.map viewNotification |> Html.ul []
                ]
            ]

        Nothing ->
            []
