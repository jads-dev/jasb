module JoeBets.Bet.Progress exposing
    ( Cancelled
    , Complete
    , Locked
    , Suggestion
    , Voting
    , cancelledDecoder
    , completeDecoder
    , encodeCancelled
    , encodeComplete
    , encodeLocked
    , encodeSuggestion
    , encodeVoting
    , lockedDecoder
    , suggestionDecoder
    , votingDecoder
    )

import JoeBets.Bet.Option as Option
import JoeBets.User.Model as User
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE


type alias Suggestion =
    { by : User.Id }


suggestionDecoder : JsonD.Decoder Suggestion
suggestionDecoder =
    JsonD.succeed Suggestion
        |> JsonD.required "by" User.idDecoder


encodeSuggestion : Suggestion -> JsonE.Value
encodeSuggestion { by } =
    JsonE.object
        [ ( "state", "Suggestion" |> JsonE.string )
        , ( "by", by |> User.encodeId )
        ]


type alias Voting =
    { locksWhen : String }


votingDecoder : JsonD.Decoder Voting
votingDecoder =
    JsonD.succeed Voting
        |> JsonD.required "locksWhen" JsonD.string


encodeVoting : Voting -> JsonE.Value
encodeVoting { locksWhen } =
    JsonE.object
        [ ( "state", "Voting" |> JsonE.string )
        , ( "locksWhen", locksWhen |> JsonE.string )
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
    { winner : Option.Id }


completeDecoder : JsonD.Decoder Complete
completeDecoder =
    JsonD.succeed Complete
        |> JsonD.required "winner" Option.idDecoder


encodeComplete : Complete -> JsonE.Value
encodeComplete { winner } =
    JsonE.object
        [ ( "state", "Complete" |> JsonE.string )
        , ( "winner", winner |> Option.idToString |> JsonE.string )
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
