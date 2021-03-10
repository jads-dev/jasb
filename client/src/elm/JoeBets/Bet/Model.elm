module JoeBets.Bet.Model exposing
    ( Bet
    , Id
    , Progress(..)
    , decoder
    , encode
    , idDecoder
    , idFromString
    , idParser
    , idToString
    )

import AssocList
import JoeBets.Bet.Option as Option exposing (Option)
import JoeBets.Bet.Progress as Progress
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Url.Parser as Url
import Util.Json.Decode as JsonD
import Util.Json.Encode as JsonE


type Progress
    = Suggestion Progress.Suggestion
    | Voting Progress.Voting
    | Locked Progress.Locked
    | Complete Progress.Complete
    | Cancelled Progress.Cancelled


progressDecoder : JsonD.Decoder Progress
progressDecoder =
    let
        byName name =
            case name of
                "Suggestion" ->
                    Progress.suggestionDecoder |> JsonD.map Suggestion

                "Voting" ->
                    Progress.votingDecoder |> JsonD.map Voting

                "Locked" ->
                    Progress.lockedDecoder |> JsonD.map Locked

                "Complete" ->
                    Progress.completeDecoder |> JsonD.map Complete

                "Cancelled" ->
                    Progress.cancelledDecoder |> JsonD.map Cancelled

                _ ->
                    JsonD.unknownValue "bet progress" name
    in
    JsonD.field "state" JsonD.string |> JsonD.andThen byName


encodeProgress : Progress -> JsonE.Value
encodeProgress progress =
    case progress of
        Suggestion suggestion ->
            Progress.encodeSuggestion suggestion

        Voting voting ->
            Progress.encodeVoting voting

        Locked locked ->
            Progress.encodeLocked locked

        Complete complete ->
            Progress.encodeComplete complete

        Cancelled cancelled ->
            Progress.encodeCancelled cancelled


type Id
    = Id String


idToString : Id -> String
idToString (Id string) =
    string


idParser : Url.Parser (Id -> a) a
idParser =
    Url.custom "BET ID" (Id >> Just)


idDecoder : JsonD.Decoder Id
idDecoder =
    JsonD.string |> JsonD.map Id


idFromString : String -> Id
idFromString =
    Id


type alias Bet =
    { name : String
    , description : String
    , spoiler : Bool
    , progress : Progress
    , options : AssocList.Dict Option.Id Option
    }


decoder : JsonD.Decoder Bet
decoder =
    let
        optionsDecoder =
            JsonD.assocListFromList (JsonD.field "id" Option.idDecoder) (JsonD.field "option" Option.decoder)
    in
    JsonD.succeed Bet
        |> JsonD.required "name" JsonD.string
        |> JsonD.required "description" JsonD.string
        |> JsonD.required "spoiler" JsonD.bool
        |> JsonD.required "progress" progressDecoder
        |> JsonD.required "options" optionsDecoder


encode : Bet -> JsonE.Value
encode bet =
    let
        encodeEntry k v =
            JsonE.object
                [ ( "id", k |> Option.idToString |> JsonE.string )
                , ( "option", v |> Option.encode )
                ]
    in
    JsonE.object
        [ ( "name", bet.name |> JsonE.string )
        , ( "description", bet.description |> JsonE.string )
        , ( "spoiler", bet.spoiler |> JsonE.bool )
        , ( "progress", bet.progress |> encodeProgress )
        , ( "options", bet.options |> JsonE.assocListToList encodeEntry )
        ]
