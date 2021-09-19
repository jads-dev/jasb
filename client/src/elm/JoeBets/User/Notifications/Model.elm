module JoeBets.User.Notifications.Model exposing
    ( BetResult(..)
    , Gifted
    , GiftedReason(..)
    , Model
    , Notification(..)
    , Reference
    , RefundReason(..)
    , Refunded
    , betFinishedDecoder
    , betResultDecoder
    , decoder
    , getId
    , giftedDecoder
    , giftedReasonDecoder
    , refundReasonDecoder
    , refundedDecoder
    )

import JoeBets.Bet.Model as Bet
import JoeBets.Bet.Option as Option
import JoeBets.Game.Model as Game
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Util.Json.Decode as JsonD


type alias Model =
    List Notification


type alias Reference a =
    { a
        | gameId : Game.Id
        , gameName : String
        , betId : Bet.Id
        , betName : String
        , optionId : Option.Id
        , optionName : String
    }


type GiftedReason
    = AccountCreated


giftedReasonDecoder : JsonD.Decoder GiftedReason
giftedReasonDecoder =
    let
        fromName name =
            case name of
                "AccountCreated" ->
                    JsonD.succeed AccountCreated

                _ ->
                    JsonD.unknownValue "gift reason" name
    in
    JsonD.string |> JsonD.andThen fromName


type alias Gifted =
    { id : Int
    , amount : Int
    , reason : GiftedReason
    }


giftedDecoder : JsonD.Decoder Gifted
giftedDecoder =
    JsonD.succeed Gifted
        |> JsonD.required "id" JsonD.int
        |> JsonD.required "amount" JsonD.int
        |> JsonD.required "reason" giftedReasonDecoder


type RefundReason
    = OptionRemoved
    | BetCancelled


refundReasonDecoder : JsonD.Decoder RefundReason
refundReasonDecoder =
    let
        fromName name =
            case name of
                "OptionRemoved" ->
                    JsonD.succeed OptionRemoved

                "BetCancelled" ->
                    JsonD.succeed BetCancelled

                _ ->
                    JsonD.unknownValue "refund reason" name
    in
    JsonD.string |> JsonD.andThen fromName


type alias Refunded =
    { id : Int
    , gameId : Game.Id
    , gameName : String
    , betId : Bet.Id
    , betName : String
    , optionId : Option.Id
    , optionName : String
    , reason : RefundReason
    , amount : Int
    }


refundedDecoder : JsonD.Decoder Refunded
refundedDecoder =
    JsonD.succeed Refunded
        |> JsonD.required "id" JsonD.int
        |> JsonD.required "gameId" Game.idDecoder
        |> JsonD.required "gameName" JsonD.string
        |> JsonD.required "betId" Bet.idDecoder
        |> JsonD.required "betName" JsonD.string
        |> JsonD.required "optionId" Option.idDecoder
        |> JsonD.required "optionName" JsonD.string
        |> JsonD.required "reason" refundReasonDecoder
        |> JsonD.required "amount" JsonD.int


type BetResult
    = Win
    | Loss


betResultDecoder : JsonD.Decoder BetResult
betResultDecoder =
    let
        fromName name =
            case name of
                "Win" ->
                    JsonD.succeed Win

                "Loss" ->
                    JsonD.succeed Loss

                _ ->
                    JsonD.unknownValue "bet result" name
    in
    JsonD.string |> JsonD.andThen fromName


type alias BetFinished =
    { id : Int
    , gameId : Game.Id
    , gameName : String
    , betId : Bet.Id
    , betName : String
    , optionId : Option.Id
    , optionName : String
    , result : BetResult
    , amount : Int
    }


betFinishedDecoder : JsonD.Decoder BetFinished
betFinishedDecoder =
    JsonD.succeed BetFinished
        |> JsonD.required "id" JsonD.int
        |> JsonD.required "gameId" Game.idDecoder
        |> JsonD.required "gameName" JsonD.string
        |> JsonD.required "betId" Bet.idDecoder
        |> JsonD.required "betName" JsonD.string
        |> JsonD.required "optionId" Option.idDecoder
        |> JsonD.required "optionName" JsonD.string
        |> JsonD.required "result" betResultDecoder
        |> JsonD.required "amount" JsonD.int


type Notification
    = Gift Gifted
    | Refund Refunded
    | BetFinish BetFinished


getId : Notification -> Int
getId notification =
    case notification of
        Gift gifted ->
            gifted.id

        Refund refunded ->
            refunded.id

        BetFinish betFinished ->
            betFinished.id


decoder : JsonD.Decoder Notification
decoder =
    let
        fromName name =
            case name of
                "Gifted" ->
                    giftedDecoder |> JsonD.map Gift

                "Refunded" ->
                    refundedDecoder |> JsonD.map Refund

                "BetFinished" ->
                    betFinishedDecoder |> JsonD.map BetFinish

                _ ->
                    JsonD.unknownValue "notification" name
    in
    JsonD.field "type" JsonD.string |> JsonD.andThen fromName
