module JoeBets.Game.Model exposing
    ( Game
    , Progress(..)
    , WithBets
    , decoder
    , finish
    , start
    , withBetsDecoder
    )

import AssocList
import JoeBets.Bet.Model as Bet exposing (Bet)
import JoeBets.Game.Progress as Progress
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Time.Date exposing (Date)
import Util.Json.Decode as JsonD


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
    , order : Maybe Int
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
        |> JsonD.optionalAsMaybe "order" JsonD.int


type alias WithBets =
    { game : Game
    , bets : AssocList.Dict Bet.Id Bet
    }


withBetsDecoder : JsonD.Decoder WithBets
withBetsDecoder =
    let
        gameWithoutGivenBetCount bets =
            JsonD.succeed Game
                |> JsonD.required "version" JsonD.int
                |> JsonD.required "name" JsonD.string
                |> JsonD.required "cover" JsonD.string
                |> JsonD.required "igdbId" JsonD.string
                |> JsonD.hardcoded bets
                |> JsonD.required "progress" progressDecoder
                |> JsonD.optionalAsMaybe "order" JsonD.int

        betsDecoder =
            JsonD.assocListFromList (JsonD.field "id" Bet.idDecoder) (JsonD.field "bet" Bet.decoder)

        fromBets bets =
            JsonD.succeed WithBets
                |> JsonD.custom (bets |> AssocList.size |> gameWithoutGivenBetCount)
                |> JsonD.hardcoded bets
    in
    JsonD.field "bets" betsDecoder |> JsonD.andThen fromBets
