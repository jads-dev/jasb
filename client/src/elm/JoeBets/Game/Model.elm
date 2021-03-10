module JoeBets.Game.Model exposing
    ( Game
    , Id
    , Progress(..)
    , decoder
    , encode
    , idDecoder
    , idFromString
    , idParser
    , idToString
    )

import JoeBets.Game.Progress as Progress
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


encodeProgress : Progress -> JsonE.Value
encodeProgress progress =
    case progress of
        Future future ->
            Progress.encodeFuture future

        Current current ->
            Progress.encodeCurrent current

        Finished finished ->
            Progress.encodeFinished finished


type alias Game =
    { name : String
    , cover : String
    , bets : Int
    , progress : Progress
    }


decoder : JsonD.Decoder Game
decoder =
    JsonD.succeed Game
        |> JsonD.required "name" JsonD.string
        |> JsonD.required "cover" JsonD.string
        |> JsonD.required "bets" JsonD.int
        |> JsonD.required "progress" progressDecoder


encode : Game -> JsonE.Value
encode game =
    JsonE.object
        [ ( "name", game.name |> JsonE.string )
        , ( "cover", game.cover |> JsonE.string )
        , ( "bets", game.bets |> JsonE.int )
        , ( "progress", game.progress |> encodeProgress )
        ]
