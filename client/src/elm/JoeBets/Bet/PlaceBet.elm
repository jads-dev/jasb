module JoeBets.Bet.PlaceBet exposing
    ( init
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
import JoeBets.Bet.Maths as Bet
import JoeBets.Bet.Model as Bet exposing (Bet)
import JoeBets.Bet.Option as Option exposing (Option)
import JoeBets.Bet.PlaceBet.Model exposing (..)
import JoeBets.Game.Model as Game
import JoeBets.User as User
import JoeBets.User.Model as User exposing (User)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Material.Button as Button
import Material.TextField as TextField
import Util.Maybe as Maybe
import Util.RemoteData as RemoteData


type alias Parent a =
    { a
        | placeBet : Model
    }


init : Model
init =
    Nothing


update : (Msg -> msg) -> (Game.Id -> Bet.Id -> Bet -> User -> msg) -> String -> Msg -> Parent a -> ( Parent a, Cmd msg )
update wrap handleSuccess origin msg model =
    case msg of
        Start target ->
            ( { model
                | placeBet =
                    Overlay target (target.existingBet |> Maybe.withDefault 100 |> String.fromInt) Nothing |> Just
              }
            , Cmd.none
            )

        Cancel ->
            ( { model | placeBet = Nothing }, Cmd.none )

        ChangeAmount newAmount ->
            let
                changeAmount overlay =
                    { overlay | amount = newAmount }
            in
            ( { model | placeBet = model.placeBet |> Maybe.map changeAmount }, Cmd.none )

        Place amount ->
            let
                tryPlaceBet { target } =
                    let
                        handle response =
                            case response of
                                Ok ( bet, user ) ->
                                    handleSuccess target.gameId target.betId bet user

                                Err error ->
                                    error |> SetError |> wrap

                        betAndUserDecoder =
                            JsonD.succeed Tuple.pair
                                |> JsonD.required "bet" Bet.decoder
                                |> JsonD.required "user" User.decoder
                    in
                    Api.post origin
                        { path =
                            [ "game"
                            , target.gameId |> Game.idToString
                            , target.betId |> Bet.idToString
                            , target.optionId |> Option.idToString
                            ]
                        , body = [ ( "amount", amount |> JsonE.int ) ] |> JsonE.object |> Http.jsonBody
                        , expect =
                            Http.expectJson handle betAndUserDecoder
                        }
            in
            ( model, model.placeBet |> Maybe.map tryPlaceBet |> Maybe.withDefault Cmd.none )

        SetError error ->
            let
                setError overlay =
                    { overlay | error = Just error }
            in
            ( { model | placeBet = model.placeBet |> Maybe.map setError }, Cmd.none )


view : (Msg -> msg) -> User.WithId -> Model -> List (Html msg)
view wrap { id, user } placeBet =
    case placeBet of
        Just { amount, target, error } ->
            let
                { gameName, bet, optionId, optionName, existingBet } =
                    target

                amountNumber =
                    amount |> String.toInt

                alreadyPaid =
                    existingBet |> Maybe.withDefault 0

                totalForOption =
                    .stakes >> AssocList.values >> List.map .amount >> List.sum

                totalAmount =
                    bet.options
                        |> AssocList.values
                        |> List.map totalForOption
                        |> List.sum

                optionAmount =
                    bet.options
                        |> AssocList.get optionId
                        |> Maybe.map totalForOption
                        |> Maybe.withDefault 0

                currentRatio =
                    Bet.ratio totalAmount optionAmount

                submit =
                    case amountNumber of
                        Just betAmount ->
                            let
                                toPay =
                                    betAmount - alreadyPaid
                            in
                            if betAmount < 0 then
                                Err "You cannot make negative bets."

                            else if toPay <= user.balance then
                                betAmount |> Place |> wrap |> Ok

                            else if betAmount <= 100 then
                                if Bet.hasAnyOtherStake bet id optionId |> not then
                                    betAmount |> Place |> wrap |> Ok

                                else
                                    Err "You can't place bets for multiple options if it leaves you with a negative balance."

                            else
                                Err "You can't place bets of more than 100 if it leaves you with a negative balance."

                        Nothing ->
                            Err "Not a valid, whole number."

                errorMessage =
                    let
                        validation =
                            case submit of
                                Ok _ ->
                                    []

                                Err e ->
                                    [ e ]
                    in
                    (validation ++ (error |> Maybe.map RemoteData.errorToString |> Maybe.toList))
                        |> List.map Html.text
                        |> Html.p [ HtmlA.class "error" ]

                description =
                    case existingBet of
                        Just _ ->
                            "Updating"

                        Nothing ->
                            "Placing"
            in
            [ Html.div [ HtmlA.class "overlay" ]
                [ Html.div [ HtmlA.class "place-bet" ]
                    [ Html.p []
                        [ Html.text description
                        , Html.text " bet on “"
                        , Html.text optionName
                        , Html.text "” for “"
                        , Html.text bet.name
                        , Html.text "” in “"
                        , Html.text gameName
                        , Html.text "” which currently has a return ratio of "
                        , Html.text currentRatio
                        , Html.text "."
                        ]
                    , Html.p [ HtmlA.class "balance" ]
                        [ Html.text "Your Balance: "
                        , User.viewBalanceOrTransaction user.balance
                            (amountNumber |> Maybe.map ((-) user.balance >> (+) alreadyPaid))
                        ]
                    , TextField.viewWithAttrs "Bet Amount"
                        TextField.Number
                        amount
                        (ChangeAmount >> wrap |> Just)
                        [ HtmlA.attribute "outlined" ""
                        , 0 |> String.fromInt |> HtmlA.min
                        , max (user.balance + (existingBet |> Maybe.withDefault 0)) 100 |> String.fromInt |> HtmlA.max
                        ]
                    , errorMessage
                    , Html.div [ HtmlA.class "controls" ]
                        [ Button.view Button.Standard
                            Button.Padded
                            "Cancel"
                            (Icon.times |> Icon.present |> Icon.view |> Just)
                            (Cancel |> wrap |> Just)
                        , Button.view Button.Raised
                            Button.Padded
                            "Place Bet"
                            (Icon.check |> Icon.present |> Icon.view |> Just)
                            (submit |> Result.toMaybe)
                        ]
                    ]
                ]
            ]

        Nothing ->
            []
