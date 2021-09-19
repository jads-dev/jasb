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
import JoeBets.Bet.PlaceBet.Model as PlaceBet exposing (..)
import JoeBets.Coins as Coins
import JoeBets.Page.User.Model as User
import JoeBets.Rules as Rules
import JoeBets.User.Model as User exposing (User)
import Json.Decode as JsonD
import Json.Encode as JsonE
import Material.Button as Button
import Material.TextField as TextField
import Time.DateTime as DateTime
import Time.Model as Time
import Util.Maybe as Maybe
import Util.RemoteData as RemoteData


type alias Parent a =
    { a
        | placeBet : Model
    }


init : Model
init =
    Nothing


update : (Msg -> msg) -> (List Change -> msg) -> String -> Time.Context -> Msg -> Parent a -> ( Parent a, Cmd msg )
update wrap handleSuccess origin time msg model =
    case msg of
        Start target ->
            let
                bet =
                    target.existingBet |> Maybe.withDefault Rules.maxBetWhileInDebt
            in
            ( { model
                | placeBet =
                    Overlay target (bet |> String.fromInt) "" Nothing |> Just
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

        ChangeMessage newMessage ->
            let
                changeMessage overlay =
                    { overlay | message = newMessage }
            in
            ( { model | placeBet = model.placeBet |> Maybe.map changeMessage }, Cmd.none )

        Place { id, user } amount message ->
            let
                tryPlaceBet { target } =
                    let
                        putOrPost =
                            if target.existingBet == Nothing then
                                "PUT"

                            else
                                "POST"

                        handle response =
                            case response of
                                Ok newBalance ->
                                    handleSuccess
                                        [ User.ChangeBalance newBalance |> PlaceBet.User id
                                        , PlaceBet.Bet target.gameId target.betId <|
                                            case target.existingBet of
                                                Just _ ->
                                                    Bet.ChangeStake target.optionId id amount message

                                                Nothing ->
                                                    Bet.AddStake target.optionId
                                                        id
                                                        { amount = amount
                                                        , message = message
                                                        , at = DateTime.fromPosix time.now
                                                        , user = user |> User.summary
                                                        }
                                        ]

                                Err error ->
                                    error |> SetError |> wrap
                    in
                    Api.request origin
                        putOrPost
                        { path =
                            Api.Game target.gameId (Api.Bet target.betId (Api.Option target.optionId Api.Stake))
                        , body =
                            [ ( "amount", amount |> JsonE.int ) |> Just
                            , message |> Maybe.map (\m -> ( "message", m |> JsonE.string ))
                            ]
                                |> List.filterMap identity
                                |> JsonE.object
                                |> Http.jsonBody
                        , expect =
                            Http.expectJson handle JsonD.int
                        }
            in
            ( model, model.placeBet |> Maybe.map tryPlaceBet |> Maybe.withDefault Cmd.none )

        Withdraw userId ->
            let
                tryWithdrawBet { target } =
                    let
                        handle response =
                            case response of
                                Ok newBalance ->
                                    handleSuccess
                                        [ User.ChangeBalance newBalance |> PlaceBet.User userId
                                        , Bet.RemoveStake target.optionId userId |> PlaceBet.Bet target.gameId target.betId
                                        ]

                                Err error ->
                                    error |> SetError |> wrap
                    in
                    Api.delete origin
                        { path = Api.Game target.gameId (Api.Bet target.betId (Api.Option target.optionId Api.Stake))
                        , body = Http.emptyBody
                        , expect = Http.expectJson handle JsonD.int
                        }
            in
            ( model, model.placeBet |> Maybe.map tryWithdrawBet |> Maybe.withDefault Cmd.none )

        SetError error ->
            let
                setError overlay =
                    { overlay | error = Just error }
            in
            ( { model | placeBet = model.placeBet |> Maybe.map setError }, Cmd.none )


view : (Msg -> msg) -> User.WithId -> Model -> List (Html msg)
view wrap ({ id, user } as localUser) placeBet =
    case placeBet of
        Just { amount, target, message, error } ->
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

                ( messageIfGiven, messageInput ) =
                    if (amountNumber |> Maybe.withDefault 0) >= Rules.notableStake then
                        ( message |> Maybe.when (message |> String.isEmpty |> not)
                        , [ Html.p []
                                [ Html.text "As you are making a big bet, you can leave a message with it. "
                                , Html.text "If you do, you won't be able to change your bet. "
                                , Html.text "You can leave it blank if you don't want to."
                                ]
                          , TextField.viewWithAttrs "Message"
                                TextField.Text
                                message
                                (ChangeMessage >> wrap |> Just)
                                [ HtmlA.attribute "outlined" "", HtmlA.maxlength 200 ]
                          , Html.p []
                                [ Html.text "Please be aware: inappropriate messages, spoilers, or anything like that will result in a ban. "
                                ]
                          ]
                        )

                    else
                        ( Nothing, [] )

                submit =
                    case amountNumber of
                        Just betAmount ->
                            let
                                toPay =
                                    betAmount - alreadyPaid

                                place =
                                    Place localUser betAmount messageIfGiven |> wrap |> Ok
                            in
                            if Just betAmount == existingBet && messageIfGiven == Nothing then
                                Err "You can change your bet."

                            else if betAmount == 0 then
                                Err "You cannot place a zero value bet, but you can cancel the bet."

                            else if betAmount < 0 then
                                Err "You cannot make negative bets."

                            else if toPay <= user.balance then
                                place

                            else if betAmount <= Rules.maxBetWhileInDebt then
                                place

                            else
                                [ "You can't place bets of more than "
                                , Rules.maxBetWhileInDebt |> String.fromInt
                                , " if it leaves you with a negative balance."
                                ]
                                    |> String.concat
                                    |> Err

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

                ( actionName, description ) =
                    case existingBet of
                        Just _ ->
                            ( "Change", "Updating" )

                        Nothing ->
                            ( "Place", "Placing" )

                contents =
                    [ [ Html.p []
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
                            , Coins.viewAmountOrTransaction user.balance
                                (amountNumber |> Maybe.map ((-) user.balance >> (+) alreadyPaid))
                            ]
                      , TextField.viewWithAttrs "Bet Amount"
                            TextField.Number
                            amount
                            (ChangeAmount >> wrap |> Just)
                            [ HtmlA.attribute "outlined" ""
                            , 0 |> String.fromInt |> HtmlA.min
                            , max (user.balance + (existingBet |> Maybe.withDefault 0)) Rules.maxBetWhileInDebt |> String.fromInt |> HtmlA.max
                            ]
                      , errorMessage
                      ]
                    , messageInput
                    , [ Html.div [ HtmlA.class "controls" ]
                            [ Button.view Button.Standard
                                Button.Padded
                                "Back"
                                (Icon.times |> Icon.present |> Icon.view |> Just)
                                (Cancel |> wrap |> Just)
                            , Html.div [ HtmlA.class "actions" ]
                                [ Html.span [ HtmlA.class "cancel" ]
                                    [ Button.view Button.Raised
                                        Button.Padded
                                        "Cancel Bet"
                                        (Icon.trash |> Icon.present |> Icon.view |> Just)
                                        (Withdraw id |> wrap |> Just)
                                    ]
                                , Button.view Button.Raised
                                    Button.Padded
                                    (actionName ++ " Bet")
                                    (Icon.check |> Icon.present |> Icon.view |> Just)
                                    (submit |> Result.toMaybe)
                                ]
                            ]
                      ]
                    ]
            in
            [ Html.div [ HtmlA.class "overlay" ] [ contents |> List.concat |> Html.div [ HtmlA.class "place-bet" ] ] ]

        Nothing ->
            []
