module JoeBets.Game.Id exposing
    ( Id
    , encodeId
    , idDecoder
    , idFromString
    , idParser
    , idToString
    )

import Json.Decode as JsonD
import Json.Encode as JsonE
import Url.Parser as Url


type Id
    = Id String


encodeId : Id -> JsonE.Value
encodeId =
    idToString >> JsonE.string


idToString : Id -> String
idToString (Id string) =
    string


idParser : Url.Parser (Id -> a) a
idParser =
    Url.custom "GAME ID" (Id >> Just)


idDecoder : JsonD.Decoder Id
idDecoder =
    JsonD.string |> JsonD.map Id


idFromString : String -> Id
idFromString =
    Id
