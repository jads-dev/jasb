module JoeBets.Game.Progress exposing
    ( Current
    , Finished
    , Future
    , currentDecoder
    , encodeCurrent
    , encodeFinished
    , encodeFuture
    , finishedDecoder
    , futureDecoder
    )

import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Time
import Util.Json.Decode as JsonD
import Util.Json.Encode as JsonE


type alias Future =
    {}


futureDecoder : JsonD.Decoder Future
futureDecoder =
    JsonD.succeed Future


encodeFuture : Future -> JsonE.Value
encodeFuture _ =
    JsonE.object
        [ ( "state", "Future" |> JsonE.string ) ]


type alias Current =
    { start : Time.Posix }


currentDecoder : JsonD.Decoder Current
currentDecoder =
    JsonD.succeed Current
        |> JsonD.required "start" JsonD.posix


encodeCurrent : Current -> JsonE.Value
encodeCurrent { start } =
    JsonE.object
        [ ( "state", "Current" |> JsonE.string )
        , ( "start", start |> JsonE.posix )
        ]


type alias Finished =
    { start : Time.Posix, finish : Time.Posix }


finishedDecoder : JsonD.Decoder Finished
finishedDecoder =
    JsonD.succeed Finished
        |> JsonD.required "start" JsonD.posix
        |> JsonD.required "finish" JsonD.posix


encodeFinished : Finished -> JsonE.Value
encodeFinished { start, finish } =
    JsonE.object
        [ ( "state", "Finished" |> JsonE.string )
        , ( "start", start |> JsonE.posix )
        , ( "start", finish |> JsonE.posix )
        ]
