module JoeBets.User.Model exposing
    ( Id
    , Summary
    , SummaryWithId
    , User
    , WithId
    , decoder
    , encodeId
    , idDecoder
    , idFromString
    , idParser
    , idToString
    , summary
    , summaryDecoder
    , summaryWithIdDecoder
    , withIdDecoder
    )

import EverySet exposing (EverySet)
import JoeBets.Game.Id as Game
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Time.DateTime as DateTime exposing (DateTime)
import Url.Parser as Url
import Util.Json.Decode as JsonD


type Id
    = Id String


idToString : Id -> String
idToString (Id string) =
    string


idParser : Url.Parser (Id -> a) a
idParser =
    Url.custom "USER ID" (Id >> Just)


idFromString : String -> Id
idFromString =
    Id


idDecoder : JsonD.Decoder Id
idDecoder =
    JsonD.string |> JsonD.map Id


encodeId : Id -> JsonE.Value
encodeId (Id string) =
    string |> JsonE.string


type alias Permissions =
    { manageGames : Bool
    , managePermissions : Bool
    , manageBets : EverySet Game.Id
    }


defaultPermissions : Permissions
defaultPermissions =
    { manageGames = False
    , managePermissions = False
    , manageBets = EverySet.empty
    }


permissionsDecoder : JsonD.Decoder Permissions
permissionsDecoder =
    JsonD.succeed Permissions
        |> JsonD.optional "manageGames" JsonD.bool False
        |> JsonD.optional "managePermissions" JsonD.bool False
        |> JsonD.optional "manageBets" (JsonD.everySetFromList Game.idDecoder) EverySet.empty


type alias User =
    { name : String
    , discriminator : Maybe String
    , avatar : String
    , balance : Int
    , betValue : Int
    , created : DateTime
    , permissions : Permissions
    }


decoder : JsonD.Decoder User
decoder =
    JsonD.succeed User
        |> JsonD.required "name" JsonD.string
        |> JsonD.optionalAsMaybe "discriminator" JsonD.string
        |> JsonD.required "avatar" JsonD.string
        |> JsonD.required "balance" JsonD.int
        |> JsonD.required "betValue" JsonD.int
        |> JsonD.required "created" DateTime.decoder
        |> JsonD.optional "permissions" permissionsDecoder defaultPermissions


type alias WithId =
    { id : Id, user : User }


withIdDecoder : JsonD.Decoder WithId
withIdDecoder =
    JsonD.map2 WithId
        (JsonD.index 0 idDecoder)
        (JsonD.index 1 decoder)


type alias Summary =
    { name : String
    , discriminator : Maybe String
    , avatar : String
    }


summary : User -> Summary
summary { name, discriminator, avatar } =
    Summary name discriminator avatar


summaryDecoder : JsonD.Decoder Summary
summaryDecoder =
    JsonD.succeed Summary
        |> JsonD.required "name" JsonD.string
        |> JsonD.optionalAsMaybe "discriminator" JsonD.string
        |> JsonD.required "avatar" JsonD.string


type alias SummaryWithId =
    { id : Id, user : Summary }


summaryWithIdDecoder : JsonD.Decoder SummaryWithId
summaryWithIdDecoder =
    JsonD.map2 SummaryWithId
        (JsonD.index 0 idDecoder)
        (JsonD.index 1 summaryDecoder)
