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
import Time.Date as Date exposing (Date)


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
    { start : Date }


currentDecoder : JsonD.Decoder Current
currentDecoder =
    JsonD.succeed Current
        |> JsonD.required "start" Date.decoder


encodeCurrent : Current -> JsonE.Value
encodeCurrent { start } =
    JsonE.object
        [ ( "state", "Current" |> JsonE.string )
        , ( "start", start |> Date.encode )
        ]


type alias Finished =
    { start : Date, finish : Date }


finishedDecoder : JsonD.Decoder Finished
finishedDecoder =
    JsonD.succeed Finished
        |> JsonD.required "start" Date.decoder
        |> JsonD.required "finish" Date.decoder


encodeFinished : Finished -> JsonE.Value
encodeFinished { start, finish } =
    JsonE.object
        [ ( "state", "Finished" |> JsonE.string )
        , ( "start", start |> Date.encode )
        , ( "finish", finish |> Date.encode )
        ]
