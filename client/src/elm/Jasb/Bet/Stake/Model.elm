module Jasb.Bet.Stake.Model exposing
    ( Stake
    , Payout
    , payoutDecoder
    , decoder
    )

import Jasb.Gacha.Balance as Gacha
import Jasb.User.Model as User
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Time.DateTime as DateTime exposing (DateTime)
import Util.Json.Decode as JsonD


type alias Payout =
    { amount : Maybe Int
    , gacha : Maybe Gacha.Value
    }


type alias Stake =
    { amount : Int
    , at : DateTime
    , user : User.Summary
    , message : Maybe String
    , payout : Maybe Payout
    }


payoutDecoder : JsonD.Decoder Payout
payoutDecoder =
    JsonD.succeed Payout
        |> JsonD.optionalAsMaybe "amount" JsonD.int
        |> JsonD.optionalAsMaybe "gacha" Gacha.valueDecoder


decoder : JsonD.Decoder Stake
decoder =
    JsonD.succeed Stake
        |> JsonD.required "amount" JsonD.int
        |> JsonD.required "at" DateTime.decoder
        |> JsonD.required "user" User.summaryDecoder
        |> JsonD.optionalAsMaybe "message" JsonD.string
        |> JsonD.optionalAsMaybe "payout" payoutDecoder
