module Jasb.Bet.Model exposing
    ( Bet
    , Change(..)
    , Id
    , Progress(..)
    , apply
    , decoder
    , encode
    , idDecoder
    , idFromString
    , idParser
    , idToString
    )

import AssocList
import Jasb.Bet.Option as Option exposing (Option)
import Jasb.Bet.Progress as Progress
import Jasb.Bet.Stake.Model exposing (Stake)
import Jasb.User.Model as User
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Url.Parser as Url
import Util.Json.Decode as JsonD
import Util.Json.Encode as JsonE


type Progress
    = Voting Progress.Voting
    | Locked Progress.Locked
    | Complete Progress.Complete
    | Cancelled Progress.Cancelled


progressDecoder : JsonD.Decoder Progress
progressDecoder =
    let
        byName name =
            case name of
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
            JsonD.assocListFromTupleList Option.idDecoder Option.decoder
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


type Change
    = Replace Bet
    | AddStake Option.Id User.Id Stake
    | RemoveStake Option.Id User.Id
    | ChangeStake Option.Id User.Id Int (Maybe String)


apply : Change -> Bet -> Bet
apply change oldBet =
    let
        modifyOption modify option =
            { option | stakes = modify option.stakes }

        modifyOptions option modify =
            { oldBet | options = oldBet.options |> AssocList.update option (Maybe.map (modifyOption modify)) }
    in
    case change of
        Replace bet ->
            bet

        AddStake option user stake ->
            modifyOptions option (AssocList.insert user stake)

        RemoveStake option user ->
            modifyOptions option (AssocList.remove user)

        ChangeStake option user amount message ->
            let
                changeStake stake =
                    { stake | amount = amount, message = message }
            in
            modifyOptions option (AssocList.update user (Maybe.map changeStake))
