module Jasb.Api.IdData exposing
    ( IdData
    , getIdData
    , getIdDataIfMissing
    , idDataToData
    , idDataToMaybe
    , ifNotIdDataLoading
    , initGetIdData
    , initIdData
    , initIdDataFromValue
    , isIdDataLoading
    , isIdDataUnstarted
    , toMaybeId
    , updateIdData
    , updateIdDataValue
    , updateIdDataWith
    , viewIdData
    , viewSpecificIdData
    )

import Html exposing (Html)
import Jasb.Api.Data exposing (..)
import Jasb.Api.Error exposing (..)
import Jasb.Api.Model exposing (..)


type IdData id value
    = IdData
        { idAndValue : Maybe ( id, Maybe value )
        , loading : Bool
        , problem : Maybe Error
        }


initIdData : IdData id value
initIdData =
    { idAndValue = Nothing, loading = False, problem = Nothing }
        |> IdData


initIdDataFromValue : id -> value -> IdData id value
initIdDataFromValue id value =
    { idAndValue = Just ( id, Just value ), loading = False, problem = Nothing }
        |> IdData


getIdData : id -> IdData id value -> Cmd msg -> ( IdData id value, Cmd msg )
getIdData id (IdData data) getRequest =
    let
        updateIdAndValue ( oldId, maybeValue ) =
            if oldId == id then
                Just ( id, maybeValue )

            else
                Nothing
    in
    ( IdData
        { data
            | loading = True
            , idAndValue =
                data.idAndValue
                    |> Maybe.andThen updateIdAndValue
                    |> Maybe.withDefault ( id, Nothing )
                    |> Just
        }
    , getRequest
    )


getIdDataIfMissing : id -> IdData id value -> Cmd msg -> ( IdData id value, Cmd msg )
getIdDataIfMissing requestId ((IdData data) as unchanged) getRequest =
    let
        maybeDoNothing =
            case data.idAndValue of
                Just ( id, Just _ ) ->
                    if id == requestId then
                        Just ( unchanged, Cmd.none )

                    else
                        Nothing

                _ ->
                    Nothing
    in
    case maybeDoNothing of
        Just result ->
            result

        Nothing ->
            getIdData requestId unchanged getRequest


initGetIdData : id -> Cmd msg -> ( IdData id value, Cmd msg )
initGetIdData id =
    getIdData id initIdData


updateIdDataValue : id -> (value -> value) -> IdData id value -> IdData id value
updateIdDataValue targetId f (IdData data) =
    let
        replacedIfMatching (( id, maybeValue ) as unchanged) =
            if targetId == id then
                ( id, maybeValue |> Maybe.map f )

            else
                unchanged
    in
    IdData { data | idAndValue = data.idAndValue |> Maybe.map replacedIfMatching }


idDataToMaybe : IdData id value -> Maybe ( id, value )
idDataToMaybe (IdData data) =
    let
        fromIdAndMaybe ( id, maybeValue ) =
            maybeValue |> Maybe.map (Tuple.pair id)
    in
    data.idAndValue |> Maybe.andThen fromIdAndMaybe


toMaybeId : IdData id value -> Maybe id
toMaybeId (IdData data) =
    data.idAndValue |> Maybe.map Tuple.first


isIdDataLoading : IdData id value -> Bool
isIdDataLoading (IdData { loading }) =
    loading


isIdDataUnstarted : IdData id value -> Bool
isIdDataUnstarted (IdData { idAndValue }) =
    idAndValue == Nothing


ifNotIdDataLoading : IdData id value -> Maybe msg -> Maybe msg
ifNotIdDataLoading data action =
    if isIdDataLoading data then
        Nothing

    else
        action


updateIdDataWith : id -> Response partial -> (partial -> value -> value) -> IdData id value -> IdData id value
updateIdDataWith id response apply ((IdData data) as unchanged) =
    case data.idAndValue of
        Just ( wantedId, oldValue ) ->
            if wantedId == id then
                let
                    updateValueOrError d =
                        case response of
                            Ok partialValue ->
                                { d
                                    | idAndValue =
                                        Just
                                            ( id
                                            , oldValue |> Maybe.map (apply partialValue)
                                            )
                                    , problem = Nothing
                                }

                            Err error ->
                                { d | problem = Just error }

                    noLongerLoading d =
                        { d | loading = False }
                in
                data |> updateValueOrError |> noLongerLoading |> IdData

            else
                unchanged

        Nothing ->
            unchanged


updateIdData : id -> Response value -> IdData id value -> IdData id value
updateIdData id response ((IdData data) as unchanged) =
    case data.idAndValue of
        Just ( wantedId, _ ) ->
            if wantedId == id then
                let
                    updateValueOrError d =
                        case response of
                            Ok value ->
                                { d
                                    | idAndValue = Just ( id, Just value )
                                    , problem = Nothing
                                }

                            Err error ->
                                { d | problem = Just error }

                    noLongerLoading d =
                        { d | loading = False }
                in
                data |> updateValueOrError |> noLongerLoading |> IdData

            else
                unchanged

        Nothing ->
            unchanged


idDataToData : IdData id value -> Maybe ( id, Data value )
idDataToData (IdData data) =
    let
        internal ( id, maybeValue ) =
            ( id, initFromAll maybeValue data.loading data.problem )
    in
    data.idAndValue |> Maybe.map internal


viewIdData : ViewModel msg -> (id -> value -> List (Html msg)) -> IdData id value -> List (Html msg)
viewIdData viewModel viewValue (IdData data) =
    let
        dataFromValue maybeValue =
            initFromAll
                maybeValue
                data.loading
                data.problem
    in
    case data.idAndValue of
        Just ( id, maybeValue ) ->
            dataFromValue maybeValue
                |> viewData viewModel (viewValue id)

        Nothing ->
            dataFromValue Nothing
                |> viewData viewModel (\_ -> [])


viewSpecificIdData : ViewModel msg -> (id -> value -> List (Html msg)) -> id -> IdData id value -> List (Html msg)
viewSpecificIdData viewModel viewValue targetId (IdData data) =
    let
        dataFromValue maybeValue =
            initFromAll
                maybeValue
                data.loading
                data.problem
    in
    case data.idAndValue of
        Just ( id, maybeValue ) ->
            if targetId == id then
                dataFromValue maybeValue
                    |> viewData viewModel (viewValue id)

            else
                initData
                    |> viewData viewModel (viewValue targetId)

        Nothing ->
            dataFromValue Nothing
                |> viewData viewModel (viewValue targetId)
