module JoeBets.Bet.PlaceBet exposing
    ( close
    , init
    , update
    , view
    )

import AssocList
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Api as Api
import JoeBets.Api.Action as Api
import JoeBets.Api.Path as Api
import JoeBets.Bet.Maths as Bet
import JoeBets.Bet.Model as Bet
import JoeBets.Bet.PlaceBet.Model exposing (..)
import JoeBets.Coins as Coins
import JoeBets.Page.User.Model as User
import JoeBets.Rules as Rules
import JoeBets.User.Model as User
import Json.Decode as JsonD
import Json.Encode as JsonE
import Material.Button as Button
import Material.Dialog as Dialog
import Material.TextField as TextField
import Time.DateTime as DateTime
import Time.Model as Time
import Util.Json.Encode.Pipeline as JsonE
import Util.Maybe as Maybe


type alias Parent a =
    { a
        | placeBet : Model
    }


init : Model
init =
    Nothing


close : Parent a -> Parent a
close parent =
    let
        internal placeBet =
            { placeBet | open = False }
    in
    { parent | placeBet = parent.placeBet |> Maybe.map internal }


update : (Msg -> msg) -> (List Change -> msg) -> String -> Time.Context -> Msg -> Parent a -> ( Parent a, Cmd msg )
update wrap handleSuccess origin time msg model =
    case msg of
        Start target ->
            let
                bet =
                    target.existingBet |> Maybe.withDefault Rules.maxStakeWhileInDebt
            in
            ( { model
                | placeBet =
                    Dialog True target (bet |> String.fromInt) "" Api.initAction |> Just
              }
            , Cmd.none
            )

        Cancel ->
            let
                changeDialog placeBet =
                    { placeBet | open = False }
            in
            ( { model | placeBet = model.placeBet |> Maybe.map changeDialog }, Cmd.none )

        ChangeAmount newAmount ->
            let
                changeAmount dialog =
                    { dialog | amount = newAmount }
            in
            ( { model | placeBet = model.placeBet |> Maybe.map changeAmount }, Cmd.none )

        ChangeMessage newMessage ->
            let
                changeMessage dialog =
                    { dialog | message = newMessage }
            in
            ( { model | placeBet = model.placeBet |> Maybe.map changeMessage }, Cmd.none )

        Place { id, user } amount message ->
            let
                tryPlaceBet ({ target } as placeBet) =
                    let
                        request =
                            if target.existingBet == Nothing then
                                Api.put

                            else
                                Api.post

                        handle response =
                            case response of
                                Ok newBalance ->
                                    handleSuccess
                                        [ User.ChangeBalance newBalance |> User id
                                        , Bet target.gameId target.betId <|
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

                        ( action, cmd ) =
                            { path =
                                Api.Stake
                                    |> Api.Option target.optionId
                                    |> Api.Bet target.betId
                                    |> Api.Game target.gameId
                            , body =
                                JsonE.startObject
                                    |> JsonE.field "amount" JsonE.int amount
                                    |> JsonE.maybeField "message" JsonE.string message
                                    |> JsonE.finishObject
                            , wrap = handle
                            , decoder = JsonD.int
                            }
                                |> request origin
                                |> Api.doAction placeBet.action
                    in
                    ( Just { placeBet | action = action }, cmd )

                ( newPlaceBet, placeBetCmd ) =
                    model.placeBet
                        |> Maybe.map tryPlaceBet
                        |> Maybe.withDefault ( model.placeBet, Cmd.none )
            in
            ( { model | placeBet = newPlaceBet }, placeBetCmd )

        Withdraw userId ->
            let
                tryWithdrawBet ({ target } as placeBet) =
                    let
                        handle response =
                            case response of
                                Ok newBalance ->
                                    handleSuccess
                                        [ User.ChangeBalance newBalance |> User userId
                                        , Bet.RemoveStake target.optionId userId |> Bet target.gameId target.betId
                                        ]

                                Err error ->
                                    error |> SetError |> wrap

                        ( action, cmd ) =
                            { path = Api.Game target.gameId (Api.Bet target.betId (Api.Option target.optionId Api.Stake))
                            , wrap = handle
                            , decoder = JsonD.int
                            }
                                |> Api.delete origin
                                |> Api.doAction placeBet.action
                    in
                    ( Just { placeBet | action = action }, cmd )

                ( newPlaceBet, placeBetCmd ) =
                    model.placeBet
                        |> Maybe.map tryWithdrawBet
                        |> Maybe.withDefault ( model.placeBet, Cmd.none )
            in
            ( { model | placeBet = newPlaceBet }, placeBetCmd )

        SetError error ->
            let
                setError dialog =
                    { dialog
                        | action =
                            dialog.action |> Api.handleActionDone (Err error)
                    }
            in
            ( { model | placeBet = model.placeBet |> Maybe.map setError }
            , Cmd.none
            )


view : (Msg -> msg) -> User.WithId -> Model -> List (Html msg)
view wrap ({ id, user } as localUser) placeBet =
    case placeBet of
        Just { open, amount, target, message, action } ->
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
                          , TextField.outlined "Message" (ChangeMessage >> wrap |> Just) message
                                |> TextField.maxLength 200
                                |> TextField.view
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
                            if Just betAmount == existingBet && messageIfGiven == Nothing then
                                Err "You have already placed the bet, you can change the value to change your stake, or delete it."

                            else if betAmount == 0 then
                                Err "You cannot place a zero value bet, but you can cancel the bet."

                            else if betAmount < Rules.minStake then
                                [ "You can't place bets of less than "
                                , Rules.minStake |> String.fromInt
                                , "."
                                ]
                                    |> String.concat
                                    |> Err

                            else if betAmount - alreadyPaid <= user.balance || betAmount <= Rules.maxStakeWhileInDebt then
                                Place localUser betAmount messageIfGiven |> wrap |> Ok

                            else
                                [ "You can't place bets of more than "
                                , Rules.maxStakeWhileInDebt |> String.fromInt
                                , " if it leaves you with a negative balance."
                                ]
                                    |> String.concat
                                    |> Err

                        Nothing ->
                            Err "Not a valid, whole number."

                validationError =
                    case submit of
                        Ok _ ->
                            []

                        Err e ->
                            [ [ Html.li [] [ Html.text e ] ]
                                |> Html.ul [ HtmlA.class "validation-errors" ]
                            ]

                ( actionName, description ) =
                    case existingBet of
                        Just _ ->
                            ( "Change", "Updating" )

                        Nothing ->
                            ( "Place", "Placing" )

                actions =
                    let
                        cancelButton =
                            if existingBet /= Nothing then
                                [ Html.span [ HtmlA.class "cancel" ]
                                    [ Button.filled "Delete Bet"
                                        |> Button.button (Withdraw id |> wrap |> Just |> Api.ifNotWorking action)
                                        |> Button.icon [ Icon.trash |> Icon.view ]
                                        |> Button.view
                                    ]
                                ]

                            else
                                []
                    in
                    cancelButton
                        ++ [ Button.filled (actionName ++ " Bet")
                                |> Button.button (submit |> Result.toMaybe |> Api.ifNotWorking action)
                                |> Button.icon [ Icon.check |> Icon.view ]
                                |> Button.view
                           ]

                dialogContents =
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
                      , TextField.outlined "Bet Amount"
                            (ChangeAmount >> wrap |> Just)
                            amount
                            |> TextField.number
                            |> TextField.attrs
                                [ 0 |> String.fromInt |> HtmlA.min
                                , max (user.balance + (existingBet |> Maybe.withDefault 0)) Rules.maxStakeWhileInDebt |> String.fromInt |> HtmlA.max
                                ]
                            |> TextField.view
                      ]
                    , validationError
                    , Api.viewAction [] action
                    , messageInput
                    ]
            in
            [ Dialog.dialog (Cancel |> wrap)
                (dialogContents |> List.concat)
                [ Button.text "Back"
                    |> Button.button (Cancel |> wrap |> Just)
                    |> Button.icon [ Icon.times |> Icon.view ]
                    |> Button.view
                , Html.div [ HtmlA.class "actions" ] actions
                ]
                open
                |> Dialog.headline [ Html.text "Your Bet" ]
                |> Dialog.attrs [ HtmlA.class "place-bet" ]
                |> Dialog.view
            ]

        Nothing ->
            []
