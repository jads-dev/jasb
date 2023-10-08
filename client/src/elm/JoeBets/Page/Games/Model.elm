module JoeBets.Page.Games.Model exposing
    ( Context
    , Filter(..)
    , Filters
    , Games
    , Model
    , Msg(..)
    , defaultFilters
    , filterBy
    , gamesDecoder
    , possibleFilters
    )

import AssocList
import EverySet exposing (EverySet)
import JoeBets.Api.Data as Api
import JoeBets.Api.Model as Api
import JoeBets.Filtering as Filtering
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game exposing (Game)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Util.Json.Decode as JsonD


type alias Context =
    { favouriteGames : EverySet Game.Id }


type Filter
    = FavouriteFilter
    | HaveBetsFilter
    | CurrentFilter
    | FutureFilter
    | FinishedFilter


possibleFilters : List Filter
possibleFilters =
    [ FavouriteFilter
    , HaveBetsFilter
    , CurrentFilter
    , FutureFilter
    , FinishedFilter
    ]


defaultFilters : EverySet Filter
defaultFilters =
    [ CurrentFilter, FutureFilter, FinishedFilter ] |> EverySet.fromList


type alias Filters =
    EverySet Filter


filterFrom : Context -> Filter -> Filtering.Criteria ( Game.Id, Game )
filterFrom context filter =
    case filter of
        FavouriteFilter ->
            Filtering.Exclude (\( id, _ ) -> context.favouriteGames |> EverySet.member id |> not)

        HaveBetsFilter ->
            Filtering.Exclude (\( _, bet ) -> bet.bets == 0)

        CurrentFilter ->
            Filtering.Include
                (\( _, bet ) ->
                    case bet.progress of
                        Game.Current _ ->
                            True

                        _ ->
                            False
                )

        FutureFilter ->
            Filtering.Include
                (\( _, bet ) ->
                    case bet.progress of
                        Game.Future _ ->
                            True

                        _ ->
                            False
                )

        FinishedFilter ->
            Filtering.Include
                (\( _, bet ) ->
                    case bet.progress of
                        Game.Finished _ ->
                            True

                        _ ->
                            False
                )


filterBy : Filters -> Context -> (( Game.Id, Game ) -> Bool)
filterBy filters context =
    let
        criteria =
            filters |> EverySet.toList |> List.map (filterFrom context)
    in
    criteria |> Filtering.combine |> Filtering.toPredicate


type alias Model =
    { games : Api.Data Games
    , filters : Filters
    }


type alias Games =
    { future : AssocList.Dict Game.Id Game
    , current : AssocList.Dict Game.Id Game
    , finished : AssocList.Dict Game.Id Game
    }


gamesDecoder : JsonD.Decoder Games
gamesDecoder =
    let
        subsetDecoder =
            JsonD.assocListFromTupleList Game.idDecoder Game.decoder
    in
    JsonD.succeed Games
        |> JsonD.required "future" subsetDecoder
        |> JsonD.required "current" subsetDecoder
        |> JsonD.required "finished" subsetDecoder


type Msg
    = Load (Api.Response Games)
    | ToggleFilter Filter
