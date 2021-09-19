module JoeBets.Bet.Editor.EditableBet exposing
    ( EditableBet
    , EditableOption
    , Progress(..)
    , decoder
    )

import AssocList
import JoeBets.Bet.Option as Option
import JoeBets.Bet.Stake.Model as Stake exposing (Stake)
import JoeBets.User.Model as User
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
        |> JsonD.required "stakes" (JsonD.assocListFromObject User.idFromString Stake.decoder)
        |> JsonD.required "version" JsonD.int
        |> JsonD.required "created" DateTime.decoder
        |> JsonD.required "modified" DateTime.decoder


type alias EditableBet =
    { name : String
    , description : String
    , spoiler : Bool
    , locksWhen : String
    , progress : Progress
    , options : AssocList.Dict Option.Id EditableOption

    -- Metadata
    , version : Int
    , created : DateTime
    , modified : DateTime
    , author : { id : User.Id, summary : User.Summary }
    }


summaryWithId : JsonD.Decoder { id : User.Id, summary : User.Summary }
summaryWithId =
    JsonD.succeed (\id summary -> { id = id, summary = summary })
        |> JsonD.required "by" User.idDecoder
        |> JsonD.required "author" User.summaryDecoder


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
        |> JsonD.required "locksWhen" JsonD.string
        |> JsonD.custom progressDecoder
        |> JsonD.required "options" (JsonD.list editableOptionDecoder |> JsonD.map (AssocList.fromListWithDerivedKey .id))
        |> JsonD.required "version" JsonD.int
        |> JsonD.required "created" DateTime.decoder
        |> JsonD.required "modified" DateTime.decoder
        |> JsonD.custom summaryWithId
