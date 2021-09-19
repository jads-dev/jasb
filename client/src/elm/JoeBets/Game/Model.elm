module JoeBets.Game.Model exposing
    ( Game
    , Id
    , Progress(..)
    , decoder
    , encodeId
    , finish
    , idDecoder
    , idFromString
    , idParser
    , idToString
    , start
    )

import JoeBets.Game.Progress as Progress
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Time.Date exposing (Date)
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
    Url.custom "GAME ID" (Id >> Just)


idDecoder : JsonD.Decoder Id
idDecoder =
    JsonD.string |> JsonD.map Id


idFromString : String -> Id
idFromString =
    Id


type Progress
    = Future Progress.Future
    | Current Progress.Current
    | Finished Progress.Finished


start : Progress -> Maybe Date
start progress =
    case progress of
        Future _ ->
            Nothing

        Current current ->
            Just current.start

        Finished finished ->
            Just finished.start


finish : Progress -> Maybe Date
finish progress =
    case progress of
        Future _ ->
            Nothing

        Current _ ->
            Nothing

        Finished finished ->
            Just finished.finish


progressDecoder : JsonD.Decoder Progress
progressDecoder =
    let
        byName name =
            case name of
                "Future" ->
                    Progress.futureDecoder |> JsonD.map Future

                "Current" ->
                    Progress.currentDecoder |> JsonD.map Current

                "Finished" ->
                    Progress.finishedDecoder |> JsonD.map Finished

                _ ->
                    JsonD.unknownValue "game progress" name
    in
    JsonD.field "state" JsonD.string |> JsonD.andThen byName


type alias Game =
    { version : Int
    , name : String
    , cover : String
    , igdbId : String
    , bets : Int
    , progress : Progress
    }


decoder : JsonD.Decoder Game
decoder =
    JsonD.succeed Game
        |> JsonD.required "version" JsonD.int
        |> JsonD.required "name" JsonD.string
        |> JsonD.required "cover" JsonD.string
        |> JsonD.required "igdbId" JsonD.string
        |> JsonD.required "bets" JsonD.int
        |> JsonD.required "progress" progressDecoder
