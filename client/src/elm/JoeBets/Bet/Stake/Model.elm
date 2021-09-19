module JoeBets.Bet.Stake.Model exposing
    ( Stake
    , decoder
    )

import JoeBets.User.Model as User
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Time.DateTime as DateTime exposing (DateTime)
import Util.Json.Decode as JsonD


type alias Stake =
    { amount : Int
    , at : DateTime
    , user : User.Summary
    , message : Maybe String
    }


decoder : JsonD.Decoder Stake
decoder =
    JsonD.succeed Stake
        |> JsonD.required "amount" JsonD.int
        |> JsonD.required "at" DateTime.decoder
        |> JsonD.required "user" User.summaryDecoder
        |> JsonD.optionalAsMaybe "message" JsonD.string
