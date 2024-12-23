module Jasb.Bet.Editor.EditableBet exposing
    ( EditableBet
    , EditableOption
    , Progress(..)
    , decoder
    )

import AssocList
import Jasb.Bet.Editor.LockMoment as LockMoment
import Jasb.Bet.Option as Option
import Jasb.Bet.Stake.Model as Stake exposing (Stake)
import Jasb.User.Model as User
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Time.DateTime as DateTime exposing (DateTime)
import Util.AssocList as AssocList
import Util.Json.Decode as JsonD


type Progress
    = Voting
    | Locked
    | Complete { resolved : DateTime }
    | Cancelled { reason : String, resolved : DateTime }


type alias EditableOption =
    { id : Option.Id
    , name : String
    , image : Maybe String
    , order : Int
    , won : Bool

    -- Immutable
    , stakes : AssocList.Dict User.Id Stake

    -- Metadata
    , version : Int
    , created : DateTime
    , modified : DateTime
    }


editableOptionDecoder : JsonD.Decoder EditableOption
editableOptionDecoder =
    JsonD.succeed EditableOption
        |> JsonD.required "id" Option.idDecoder
        |> JsonD.required "name" JsonD.string
        |> JsonD.optionalAsMaybe "image" JsonD.string
        |> JsonD.required "order" JsonD.int
        |> JsonD.optional "won" JsonD.bool False
        |> JsonD.required "stakes" (JsonD.assocListFromTupleList User.idDecoder Stake.decoder)
        |> JsonD.required "version" JsonD.int
        |> JsonD.required "created" DateTime.decoder
        |> JsonD.required "modified" DateTime.decoder


type alias EditableBet =
    { name : String
    , description : String
    , spoiler : Bool
    , lockMoment : LockMoment.Id
    , progress : Progress
    , options : AssocList.Dict Option.Id EditableOption

    -- Metadata
    , version : Int
    , created : DateTime
    , modified : DateTime
    , author : User.SummaryWithId
    }


progressDecoder : JsonD.Decoder Progress
progressDecoder =
    let
        byName name =
            case name of
                "Voting" ->
                    JsonD.succeed Voting

                "Locked" ->
                    JsonD.succeed Locked

                "Complete" ->
                    JsonD.succeed (\r -> Complete { resolved = r })
                        |> JsonD.required "resolved" DateTime.decoder

                "Cancelled" ->
                    JsonD.succeed (\rn rd -> Cancelled { reason = rn, resolved = rd })
                        |> JsonD.required "cancelledReason" JsonD.string
                        |> JsonD.required "resolved" DateTime.decoder

                _ ->
                    JsonD.unknownValue "bet progress" name
    in
    JsonD.field "progress" JsonD.string |> JsonD.andThen byName


decoder : JsonD.Decoder EditableBet
decoder =
    JsonD.succeed EditableBet
        |> JsonD.required "name" JsonD.string
        |> JsonD.required "description" JsonD.string
        |> JsonD.required "spoiler" JsonD.bool
        |> JsonD.required "lockMoment" LockMoment.idDecoder
        |> JsonD.custom progressDecoder
        |> JsonD.required "options" (JsonD.list editableOptionDecoder |> JsonD.map (AssocList.fromListWithDerivedKey .id))
        |> JsonD.required "version" JsonD.int
        |> JsonD.required "created" DateTime.decoder
        |> JsonD.required "modified" DateTime.decoder
        |> JsonD.required "author" User.summaryWithIdDecoder
