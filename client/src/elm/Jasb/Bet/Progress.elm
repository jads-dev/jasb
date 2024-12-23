module Jasb.Bet.Progress exposing
    ( Cancelled
    , Complete
    , Locked
    , Voting
    , cancelledDecoder
    , completeDecoder
    , encodeCancelled
    , encodeComplete
    , encodeLocked
    , encodeVoting
    , lockedDecoder
    , votingDecoder
    )

import EverySet exposing (EverySet)
import Jasb.Bet.Option as Option
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Util.Json.Decode as JsonD


type alias Voting =
    { lockMoment : String }


votingDecoder : JsonD.Decoder Voting
votingDecoder =
    JsonD.succeed Voting
        |> JsonD.required "lockMoment" JsonD.string


encodeVoting : Voting -> JsonE.Value
encodeVoting { lockMoment } =
    JsonE.object
        [ ( "state", "Voting" |> JsonE.string )
        , ( "lockMoment", lockMoment |> JsonE.string )
        ]


type alias Locked =
    {}


lockedDecoder : JsonD.Decoder Locked
lockedDecoder =
    JsonD.succeed Locked


encodeLocked : Locked -> JsonE.Value
encodeLocked _ =
    JsonE.object [ ( "state", "Locked" |> JsonE.string ) ]


type alias Complete =
    { winners : EverySet Option.Id }


completeDecoder : JsonD.Decoder Complete
completeDecoder =
    JsonD.succeed Complete
        |> JsonD.required "winners" (JsonD.everySetFromList Option.idDecoder)


encodeComplete : Complete -> JsonE.Value
encodeComplete { winners } =
    JsonE.object
        [ ( "state", "Complete" |> JsonE.string )
        , ( "winners", winners |> EverySet.toList |> JsonE.list (Option.idToString >> JsonE.string) )
        ]


type alias Cancelled =
    { reason : String }


cancelledDecoder : JsonD.Decoder Cancelled
cancelledDecoder =
    JsonD.succeed Cancelled
        |> JsonD.required "reason" JsonD.string


encodeCancelled : Cancelled -> JsonE.Value
encodeCancelled { reason } =
    JsonE.object
        [ ( "state", "Cancelled" |> JsonE.string )
        , ( "reason", reason |> JsonE.string )
        ]
