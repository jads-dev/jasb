module Jasb.User.Notifications.Model exposing
    ( BetResult(..)
    , BetReverted
    , GachaAmount
    , GachaGiftedCard
    , GachaGiftedCardReason(..)
    , GachaGiftedReason(..)
    , Gifted
    , GiftedReason(..)
    , Id
    , Model
    , Msg(..)
    , Notification(..)
    , Reference
    , RefundReason(..)
    , Refunded
    , RevertFrom(..)
    , SpecialReason
    , betFinishedDecoder
    , betResultDecoder
    , decoder
    , encodeId
    , getId
    , giftedDecoder
    , giftedReasonDecoder
    , idDecoder
    , idFromInt
    , idParser
    , idToInt
    , refundReasonDecoder
    , refundedDecoder
    )

import Jasb.Api.Model as Api
import Jasb.Bet.Model as Bet
import Jasb.Bet.Option as Option
import Jasb.Gacha.Balance.Rolls as Balance
import Jasb.Gacha.Balance.Scrap as Balance
import Jasb.Gacha.Banner as Banner
import Jasb.Gacha.Card as Card
import Jasb.Game.Id as Game
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Url.Parser as Url
import Util.Json.Decode as JsonD


type Msg
    = Request
    | Load (Api.Response Model)
    | Append (Result JsonD.Error Notification)
    | SetRead Id
    | NoOp String


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


type Id
    = Id Int


idToInt : Id -> Int
idToInt (Id int) =
    int


encodeId : Id -> JsonE.Value
encodeId =
    idToInt >> JsonE.int


idParser : Url.Parser (Id -> a) a
idParser =
    Url.custom "CARDT TYPE ID" (String.toInt >> Maybe.map Id)


idDecoder : JsonD.Decoder Id
idDecoder =
    JsonD.int |> JsonD.map Id


idFromInt : Int -> Id
idFromInt =
    Id


type alias GachaAmount =
    { rolls : Maybe Balance.Rolls
    , scrap : Maybe Balance.Scrap
    }


gachaAmountDecoder : JsonD.Decoder GachaAmount
gachaAmountDecoder =
    JsonD.succeed GachaAmount
        |> JsonD.optionalAsMaybe "rolls" Balance.rollsDecoder
        |> JsonD.optionalAsMaybe "scrap" Balance.scrapDecoder


type alias SpecialReason =
    { reason : String }


type GiftedReason
    = AccountCreated
    | Bankruptcy
    | SpecialGifted SpecialReason


giftedReasonDecoder : JsonD.Decoder GiftedReason
giftedReasonDecoder =
    let
        fromName name =
            case name of
                "AccountCreated" ->
                    JsonD.succeed AccountCreated

                "Bankruptcy" ->
                    JsonD.succeed Bankruptcy

                _ ->
                    JsonD.unknownValue "gift reason" name
    in
    JsonD.oneOf
        [ JsonD.string |> JsonD.andThen fromName
        , JsonD.field "special" JsonD.string
            |> JsonD.map (SpecialReason >> SpecialGifted)
        ]


type alias Gifted =
    { id : Id
    , amount : Int
    , reason : GiftedReason
    }


giftedDecoder : JsonD.Decoder Gifted
giftedDecoder =
    JsonD.succeed Gifted
        |> JsonD.required "id" idDecoder
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
    { id : Id
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
        |> JsonD.required "id" idDecoder
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
    { id : Id
    , gameId : Game.Id
    , gameName : String
    , betId : Bet.Id
    , betName : String
    , optionId : Option.Id
    , optionName : String
    , result : BetResult
    , amount : Int
    , gachaAmount : GachaAmount
    }


betFinishedDecoder : JsonD.Decoder BetFinished
betFinishedDecoder =
    JsonD.succeed BetFinished
        |> JsonD.required "id" idDecoder
        |> JsonD.required "gameId" Game.idDecoder
        |> JsonD.required "gameName" JsonD.string
        |> JsonD.required "betId" Bet.idDecoder
        |> JsonD.required "betName" JsonD.string
        |> JsonD.required "optionId" Option.idDecoder
        |> JsonD.required "optionName" JsonD.string
        |> JsonD.required "result" betResultDecoder
        |> JsonD.required "amount" JsonD.int
        |> JsonD.optional "gachaAmount" gachaAmountDecoder { rolls = Nothing, scrap = Nothing }


type RevertFrom
    = Cancelled
    | Complete


revertFromDecoder : JsonD.Decoder RevertFrom
revertFromDecoder =
    let
        fromName name =
            case name of
                "Cancelled" ->
                    JsonD.succeed Cancelled

                "Complete" ->
                    JsonD.succeed Complete

                _ ->
                    JsonD.unknownValue "revert type" name
    in
    JsonD.string |> JsonD.andThen fromName


type alias BetReverted =
    { id : Id
    , gameId : Game.Id
    , gameName : String
    , betId : Bet.Id
    , betName : String
    , optionId : Option.Id
    , optionName : String
    , reverted : RevertFrom
    , amount : Int
    , gachaAmount : GachaAmount
    }


betRevertedDecoder : JsonD.Decoder BetReverted
betRevertedDecoder =
    JsonD.succeed BetReverted
        |> JsonD.required "id" idDecoder
        |> JsonD.required "gameId" Game.idDecoder
        |> JsonD.required "gameName" JsonD.string
        |> JsonD.required "betId" Bet.idDecoder
        |> JsonD.required "betName" JsonD.string
        |> JsonD.required "optionId" Option.idDecoder
        |> JsonD.required "optionName" JsonD.string
        |> JsonD.required "reverted" revertFromDecoder
        |> JsonD.required "amount" JsonD.int
        |> JsonD.optional "gachaAmount" gachaAmountDecoder { rolls = Nothing, scrap = Nothing }


type GachaGiftedReason
    = Historic
    | SpecialGachaGifted SpecialReason


gachaGiftedReasonDecoder : JsonD.Decoder GachaGiftedReason
gachaGiftedReasonDecoder =
    let
        fromName name =
            case name of
                "Historic" ->
                    JsonD.succeed Historic

                _ ->
                    JsonD.unknownValue "gacha gift reason" name
    in
    JsonD.oneOf
        [ JsonD.string |> JsonD.andThen fromName
        , JsonD.field "special" JsonD.string
            |> JsonD.map (SpecialReason >> SpecialGachaGifted)
        ]


type alias GachaGifted =
    { id : Id
    , amount : GachaAmount
    , reason : GachaGiftedReason
    }


gachaGiftedDecoder : JsonD.Decoder GachaGifted
gachaGiftedDecoder =
    JsonD.succeed GachaGifted
        |> JsonD.required "id" idDecoder
        |> JsonD.required "amount" gachaAmountDecoder
        |> JsonD.required "reason" gachaGiftedReasonDecoder


type GachaGiftedCardReason
    = SelfMade
    | SpecialGachaGiftedCard SpecialReason


gachaGiftedCardReasonDecoder : JsonD.Decoder GachaGiftedCardReason
gachaGiftedCardReasonDecoder =
    let
        fromName name =
            case name of
                "SelfMade" ->
                    JsonD.succeed SelfMade

                _ ->
                    JsonD.unknownValue "gacha gift card reason" name
    in
    JsonD.oneOf
        [ JsonD.string |> JsonD.andThen fromName
        , JsonD.field "special" JsonD.string
            |> JsonD.map (SpecialReason >> SpecialGachaGiftedCard)
        ]


type alias GachaGiftedCard =
    { id : Id
    , reason : GachaGiftedCardReason
    , banner : Banner.Id
    , card : Card.Id
    }


gachaGiftedCardDecoder : JsonD.Decoder GachaGiftedCard
gachaGiftedCardDecoder =
    JsonD.succeed GachaGiftedCard
        |> JsonD.required "id" idDecoder
        |> JsonD.required "reason" gachaGiftedCardReasonDecoder
        |> JsonD.required "banner" Banner.idDecoder
        |> JsonD.required "card" Card.idDecoder


type Notification
    = Gift Gifted
    | Refund Refunded
    | BetFinish BetFinished
    | BetRevert BetReverted
    | GachaGift GachaGifted
    | GachaGiftCard GachaGiftedCard


getId : Notification -> Id
getId notification =
    case notification of
        Gift { id } ->
            id

        Refund { id } ->
            id

        BetFinish { id } ->
            id

        BetRevert { id } ->
            id

        GachaGift { id } ->
            id

        GachaGiftCard { id } ->
            id


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

                "BetReverted" ->
                    betRevertedDecoder |> JsonD.map BetRevert

                "GachaGifted" ->
                    gachaGiftedDecoder |> JsonD.map GachaGift

                "GachaGiftedCard" ->
                    gachaGiftedCardDecoder |> JsonD.map GachaGiftCard

                _ ->
                    JsonD.unknownValue "notification" name
    in
    JsonD.field "type" JsonD.string |> JsonD.andThen fromName
