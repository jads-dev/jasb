module JoeBets.Bet.Stake exposing
    ( Stake
    , decoder
    )

import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Time
import Util.Json.Decode as JsonD


type alias Stake =
    { amount : Int
    , at : Time.Posix
    }


decoder : JsonD.Decoder Stake
decoder =
    JsonD.succeed Stake
        |> JsonD.required "amount" JsonD.int
        |> JsonD.required "at" JsonD.posix
