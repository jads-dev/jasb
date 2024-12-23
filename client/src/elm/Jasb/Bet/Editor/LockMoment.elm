module Jasb.Bet.Editor.LockMoment exposing
    ( Context
    , Id
    , LockMoment
    , LockMoments
    , decoder
    , encodeId
    , exists
    , idDecoder
    , idFromString
    , idParser
    , idToString
    , lockMomentsDecoder
    , name
    , order
    , version
    )

import AssocList
import Jasb.Api.Data exposing (Data)
import Jasb.Game.Id as Game
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Time.DateTime as DateTime exposing (DateTime)
import Url.Parser as Url
import Util.Json.Decode as JsonD


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
    Url.custom "LOCK MOMENT ID" (Id >> Just)


idDecoder : JsonD.Decoder Id
idDecoder =
    JsonD.string |> JsonD.map Id


idFromString : String -> Id
idFromString =
    Id


type alias LockMoment =
    { name : String
    , order : Int
    , bets : Int
    , version : Int
    , created : DateTime
    , modified : DateTime
    }


decoder : JsonD.Decoder LockMoment
decoder =
    JsonD.succeed LockMoment
        |> JsonD.required "name" JsonD.string
        |> JsonD.required "order" JsonD.int
        |> JsonD.required "bets" JsonD.int
        |> JsonD.required "version" JsonD.int
        |> JsonD.required "created" DateTime.decoder
        |> JsonD.required "modified" DateTime.decoder


type alias LockMoments =
    AssocList.Dict Id LockMoment


lockMomentsDecoder : JsonD.Decoder LockMoments
lockMomentsDecoder =
    JsonD.assocListFromTupleList idDecoder decoder


exists : LockMoments -> Maybe Id -> Bool
exists lockMoments expected =
    case expected of
        Just id ->
            AssocList.get id lockMoments /= Nothing

        Nothing ->
            False


name : LockMoments -> Id -> String
name lockMoments lockMoment =
    AssocList.get lockMoment lockMoments
        |> Maybe.map .name
        |> Maybe.withDefault ("Lock Moment “" ++ idToString lockMoment ++ "”")


order : LockMoments -> Id -> Int
order lockMoments lockMoment =
    AssocList.get lockMoment lockMoments
        |> Maybe.map .order
        |> Maybe.withDefault 0


version : LockMoments -> Id -> Int
version lockMoments lockMoment =
    AssocList.get lockMoment lockMoments
        |> Maybe.map .version
        |> Maybe.withDefault 0


type alias Context =
    { game : Game.Id
    , lockMoments : Data LockMoments
    }
