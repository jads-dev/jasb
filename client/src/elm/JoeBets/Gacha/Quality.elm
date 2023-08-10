module JoeBets.Gacha.Quality exposing
    ( Detailed
    , DetailedQualities
    , Id
    , Like
    , Likes
    , Qualities
    , Quality
    , WithId
    , class
    , decoder
    , detailedDecoder
    , detailedQualitiesDecoder
    , fromDetailed
    , fromDetailedQualities
    , idDecoder
    , idFromString
    , idParser
    , idToString
    , qualitiesDecoder
    , withIdDecoder
    )

import AssocList
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Url.Parser as Url
import Util.Json.Decode as JsonD


type Id
    = Id String


idToString : Id -> String
idToString (Id string) =
    string


idParser : Url.Parser (Id -> a) a
idParser =
    Url.custom "QUALITY ID" (Id >> Just)


idDecoder : JsonD.Decoder Id
idDecoder =
    JsonD.string |> JsonD.map Id


idFromString : String -> Id
idFromString =
    Id


class : Id -> String
class id =
    "quality-" ++ idToString id


type alias Quality =
    { name : String
    }


decoder : JsonD.Decoder Quality
decoder =
    JsonD.succeed Quality
        |> JsonD.required "name" JsonD.string


type alias WithId =
    ( Id, Quality )


withIdDecoder : JsonD.Decoder WithId
withIdDecoder =
    JsonD.map2 Tuple.pair
        (JsonD.index 0 idDecoder)
        (JsonD.index 1 decoder)


type alias Qualities =
    AssocList.Dict Id Quality


qualitiesDecoder : JsonD.Decoder Qualities
qualitiesDecoder =
    JsonD.assocListFromTupleList idDecoder decoder


type alias Detailed =
    { quality : Quality
    , description : String
    }


detailedDecoder : JsonD.Decoder Detailed
detailedDecoder =
    JsonD.succeed Detailed
        |> JsonD.custom decoder
        |> JsonD.required "description" JsonD.string


fromDetailed : Detailed -> Quality
fromDetailed =
    .quality


type alias DetailedQualities =
    AssocList.Dict Id Detailed


detailedQualitiesDecoder : JsonD.Decoder DetailedQualities
detailedQualitiesDecoder =
    JsonD.assocListFromTupleList idDecoder detailedDecoder


fromDetailedQualities : DetailedQualities -> Qualities
fromDetailedQualities =
    AssocList.map (\_ -> fromDetailed)


type alias Like a =
    { a | name : String }


type alias Likes a =
    AssocList.Dict Id (Like a)
