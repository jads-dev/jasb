module JoeBets.Page.Bets.Filters exposing
    ( Filter(..)
    , Filters
    , Resolved
    , allFilters
    , any
    , decoder
    , encode
    , init
    , merge
    , parser
    , resolve
    , resolveDefaults
    , toPairs
    , toQueries
    , update
    )

import Dict
import Json.Decode as JsonD
import Json.Encode as JsonE
import Url.Builder exposing (QueryParameter)
import Url.Parser.Query as Parser exposing (Parser)
import Util.Json.Decode as JsonD
import Util.List as List
import Util.Maybe as Maybe


type alias Filters =
    { spoilers : Maybe Bool
    , voting : Maybe Bool
    , locked : Maybe Bool
    , complete : Maybe Bool
    , cancelled : Maybe Bool
    , hasBet : Maybe Bool
    }


decoder : JsonD.Decoder Filters
decoder =
    let
        optionalFilter filter =
            JsonD.optionalAsMaybe (filter |> filterToString) JsonD.bool
    in
    JsonD.succeed Filters
        |> optionalFilter Spoilers
        |> optionalFilter Voting
        |> optionalFilter Locked
        |> optionalFilter Complete
        |> optionalFilter Cancelled
        |> optionalFilter HasBet


encode : Filters -> JsonE.Value
encode =
    let
        toProperty ( f, v ) =
            ( filterToString f, JsonE.bool v )
    in
    toPairs >> List.map toProperty >> JsonE.object


type alias Resolved =
    { spoilers : Bool
    , voting : Bool
    , locked : Bool
    , complete : Bool
    , cancelled : Bool
    , hasBet : Bool
    }


default : Resolved
default =
    { spoilers = False
    , voting = True
    , locked = True
    , complete = True
    , cancelled = False
    , hasBet = True
    }


init : Filters
init =
    { spoilers = Nothing
    , voting = Nothing
    , locked = Nothing
    , complete = Nothing
    , cancelled = Nothing
    , hasBet = Nothing
    }


resolve : Resolved -> Filters -> Resolved
resolve base modifiers =
    { spoilers = modifiers.spoilers |> Maybe.withDefault base.spoilers
    , voting = modifiers.voting |> Maybe.withDefault base.voting
    , locked = modifiers.locked |> Maybe.withDefault base.locked
    , complete = modifiers.complete |> Maybe.withDefault base.complete
    , cancelled = modifiers.cancelled |> Maybe.withDefault base.cancelled
    , hasBet = modifiers.hasBet |> Maybe.withDefault base.hasBet
    }


merge : Filters -> Filters -> Filters
merge new base =
    { spoilers = new.spoilers |> Maybe.or base.spoilers
    , voting = new.voting |> Maybe.or base.voting
    , locked = new.locked |> Maybe.or base.locked
    , complete = new.complete |> Maybe.or base.complete
    , cancelled = new.cancelled |> Maybe.or base.cancelled
    , hasBet = new.hasBet |> Maybe.or base.hasBet
    }


resolveDefaults : Filters -> Resolved
resolveDefaults =
    resolve default


update : Filter -> Bool -> Filters -> Filters
update filter visible filters =
    case filter of
        Spoilers ->
            { filters | spoilers = Just visible }

        Voting ->
            { filters | voting = Just visible }

        Locked ->
            { filters | locked = Just visible }

        Complete ->
            { filters | complete = Just visible }

        Cancelled ->
            { filters | cancelled = Just visible }

        HasBet ->
            { filters | hasBet = Just visible }


type Filter
    = Spoilers
    | Voting
    | Locked
    | Complete
    | Cancelled
    | HasBet


allFilters : List Filter
allFilters =
    [ Voting, Locked, Complete, Cancelled, HasBet, Spoilers ]


parser : Parser (Maybe Filters)
parser =
    let
        boolParser filter =
            Parser.enum (filter |> filterToString) (Dict.fromList [ ( "true", True ), ( "false", False ) ])

        base =
            Parser.map6 Filters
                (Spoilers |> boolParser)
                (Voting |> boolParser)
                (Locked |> boolParser)
                (Complete |> boolParser)
                (Cancelled |> boolParser)
                (HasBet |> boolParser)

        nothingIfNone filters =
            filters |> Maybe.when (filters |> toPairs |> List.isEmpty |> not)
    in
    base |> Parser.map nothingIfNone


filterToString : Filter -> String
filterToString filter =
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


toQueries : Filters -> List QueryParameter
toQueries =
    let
        toQuery ( filter, state ) =
            let
                value =
                    if state then
                        "true"

                    else
                        "false"
            in
            Url.Builder.string (filterToString filter) value
    in
    toPairs >> List.map toQuery


toPairs : Filters -> List ( Filter, Bool )
toPairs { spoilers, voting, locked, complete, cancelled, hasBet } =
    [ ( Spoilers, spoilers )
    , ( Voting, voting )
    , ( Locked, locked )
    , ( Complete, complete )
    , ( Cancelled, cancelled )
    , ( HasBet, hasBet )
    ]
        |> List.filterJust


any : Filters -> Bool
any =
    toPairs >> List.isEmpty >> not
