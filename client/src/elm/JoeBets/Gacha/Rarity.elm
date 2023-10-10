module JoeBets.Gacha.Rarity exposing
    ( Id
    , Rarities
    , Rarity
    , WithId
    , class
    , decoder
    , encodeId
    , idDecoder
    , idFromString
    , idParser
    , idToString
    , raritiesDecoder
    , withIdDecoder
    )

import AssocList
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Url.Parser as Url
import Util.Json.Decode as JsonD


type Id
    = Id String


idToString : Id -> String
idToString (Id string) =
    string


idParser : Url.Parser (Id -> a) a
idParser =
    Url.custom "RARITY ID" (Id >> Just)


idDecoder : JsonD.Decoder Id
idDecoder =
    JsonD.string |> JsonD.map Id


encodeId : Id -> JsonE.Value
encodeId =
    idToString >> JsonE.string


idFromString : String -> Id
idFromString =
    Id


class : Id -> String
class id =
    "rarity-" ++ idToString id


type alias Rarity =
    { name : String
    }


decoder : JsonD.Decoder Rarity
decoder =
    JsonD.succeed Rarity
        |> JsonD.required "name" JsonD.string


type alias WithId =
    ( Id, Rarity )


withIdDecoder : JsonD.Decoder WithId
withIdDecoder =
    JsonD.map2 Tuple.pair
        (JsonD.index 0 idDecoder)
        (JsonD.index 1 decoder)


type alias Rarities =
    AssocList.Dict Id Rarity


raritiesDecoder : JsonD.Decoder Rarities
raritiesDecoder =
    JsonD.assocListFromTupleList idDecoder decoder
