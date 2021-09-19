module JoeBets.User.Model exposing
    ( Id
    , Summary
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
    , withIdDecoder
    )

import EverySet exposing (EverySet)
import JoeBets.Game.Model as Game
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


type alias User =
    { name : String
    , discriminator : String
    , avatar : Maybe String
    , balance : Int
    , betValue : Int
    , created : DateTime
    , admin : Bool
    , mod : EverySet Game.Id
    }


decoder : JsonD.Decoder User
decoder =
    JsonD.succeed User
        |> JsonD.required "name" JsonD.string
        |> JsonD.required "discriminator" JsonD.string
        |> JsonD.optionalAsMaybe "avatar" JsonD.string
        |> JsonD.required "balance" JsonD.int
        |> JsonD.required "betValue" JsonD.int
        |> JsonD.required "created" DateTime.decoder
        |> JsonD.optional "admin" JsonD.bool False
        |> JsonD.optional "mod" (JsonD.everySetFromList Game.idDecoder) EverySet.empty


type alias WithId =
    { id : Id, user : User }


withIdDecoder : JsonD.Decoder WithId
withIdDecoder =
    JsonD.succeed WithId
        |> JsonD.required "id" idDecoder
        |> JsonD.required "user" decoder


type alias Summary =
    { name : String
    , discriminator : String
    , avatar : Maybe String
    }


summary : User -> Summary
summary { name, discriminator, avatar } =
    Summary name discriminator avatar


summaryDecoder : JsonD.Decoder Summary
summaryDecoder =
    JsonD.succeed Summary
        |> JsonD.required "name" JsonD.string
        |> JsonD.required "discriminator" JsonD.string
        |> JsonD.optionalAsMaybe "avatar" JsonD.string
