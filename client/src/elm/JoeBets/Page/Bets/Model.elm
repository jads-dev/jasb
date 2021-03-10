module JoeBets.Page.Bets.Model exposing
    ( Filter(..)
    , Filters
    , GameBets
    , Model
    , Msg(..)
    , ResolvedFilters
    , filtersParser
    , filtersToPairs
    , filtersToQueries
    , gameBetsDecoder
    , initFilters
    , resolveFilters
    )

import AssocList
import Dict
import JoeBets.Bet.Model as Bet exposing (Bet)
import JoeBets.Bet.PlaceBet.Model as PlaceBet
import JoeBets.Game.Model as Game exposing (Game)
import JoeBets.User.Model exposing (User)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Url.Builder exposing (QueryParameter)
import Url.Parser.Query as Parser exposing (Parser)
import Util.Json.Decode as JsonD
import Util.List as List
import Util.Maybe as Maybe
import Util.RemoteData as RemoteData exposing (RemoteData)


type alias Filters =
    { spoilers : Maybe Bool
    , voting : Maybe Bool
    , locked : Maybe Bool
    , complete : Maybe Bool
    , cancelled : Maybe Bool
    , hasBet : Maybe Bool
    }


type alias ResolvedFilters =
    { spoilers : Bool
    , voting : Bool
    , locked : Bool
    , complete : Bool
    , cancelled : Bool
    , hasBet : Bool
    }


initFilters : Filters
initFilters =
    { spoilers = Nothing
    , voting = Nothing
    , locked = Nothing
    , complete = Nothing
    , cancelled = Nothing
    , hasBet = Nothing
    }


resolveFilters : ResolvedFilters -> Filters -> ResolvedFilters
resolveFilters default modifiers =
    { spoilers = modifiers.spoilers |> Maybe.withDefault default.spoilers
    , voting = modifiers.voting |> Maybe.withDefault default.voting
    , locked = modifiers.locked |> Maybe.withDefault default.locked
    , complete = modifiers.complete |> Maybe.withDefault default.complete
    , cancelled = modifiers.cancelled |> Maybe.withDefault default.cancelled
    , hasBet = modifiers.hasBet |> Maybe.withDefault default.hasBet
    }


type Filter
    = Spoilers
    | Voting
    | Locked
    | Complete
    | Cancelled
    | HasBet


filtersParser : Parser (Maybe Filters)
filtersParser =
    let
        boolParser name =
            Parser.enum name (Dict.fromList [ ( "true", True ), ( "false", False ) ])

        base =
            Parser.map6 Filters
                (boolParser "spoilers")
                (boolParser "voting")
                (boolParser "locked")
                (boolParser "finished")
                (boolParser "cancelled")
                (boolParser "have-bet")

        nothingIfNone filters =
            filters |> Maybe.when (filters |> filtersToPairs |> List.isEmpty |> not)
    in
    base |> Parser.map nothingIfNone


filtersToQueries : Filters -> List QueryParameter
filtersToQueries =
    let
        toQuery ( filter, state ) =
            let
                name =
                    case filter of
                        Spoilers ->
                            "spoilers"

                        Voting ->
                            "voting"

                        Locked ->
                            "locked"

                        Complete ->
                            "finished"

                        Cancelled ->
                            "cancelled"

                        HasBet ->
                            "have-bet"

                value =
                    if state then
                        "true"

                    else
                        "false"
            in
            Url.Builder.string name value
    in
    filtersToPairs >> List.map toQuery


filtersToPairs : Filters -> List ( Filter, Bool )
filtersToPairs { spoilers, voting, locked, complete, cancelled, hasBet } =
    [ ( Spoilers, spoilers )
    , ( Voting, voting )
    , ( Locked, locked )
    , ( Complete, complete )
    , ( Cancelled, cancelled )
    , ( HasBet, hasBet )
    ]
        |> List.filterJust


type alias GameBets =
    { game : Game
    , bets : AssocList.Dict Bet.Id Bet
    }


gameBetsDecoder : JsonD.Decoder GameBets
gameBetsDecoder =
    let
        decoder =
            JsonD.assocListFromList (JsonD.field "id" Bet.idDecoder) (JsonD.field "bet" Bet.decoder)
    in
    JsonD.succeed GameBets
        |> JsonD.required "game" Game.decoder
        |> JsonD.required "bets" decoder


type alias Model =
    { gameBets : Maybe ( Game.Id, RemoteData GameBets )
    , filters : Filters
    , placeBet : PlaceBet.Model
    }


type Msg
    = Load Game.Id (RemoteData.Response GameBets)
    | SetFilter Filter Bool
    | Update Game.Id Bet.Id Bet User
    | PlaceBetMsg PlaceBet.Msg
