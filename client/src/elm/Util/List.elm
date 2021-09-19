module Util.List exposing
    ( addBeforeLast
    , filterJust
    , fromNonEmpty
    , insertAt
    , moveTo
    )

import List exposing (..)
import List.Extra exposing (..)


fromNonEmpty : ( a, List a ) -> List a
fromNonEmpty ( first, rest ) =
    first :: rest


filterJust : List ( a, Maybe b ) -> List ( a, b )
filterJust =
    filterMap (\( a, b ) -> b |> Maybe.map (\justB -> ( a, justB )))


insertAt : Int -> a -> List a -> List a
insertAt index item items =
    let
        ( start, end ) =
            splitAt index items
    in
    start ++ (item :: end)


moveTo : Int -> Int -> List a -> List a
moveTo from to items =
    if from == to then
        items

    else
        case items |> getAt from of
            Just found ->
                let
                    toAdjusted =
                        if from < to then
                            to - 1

                        else
                            to
                in
                items
                    |> removeAt from
                    |> insertAt toAdjusted found

            Nothing ->
                items


addBeforeLast : a -> List a -> List a
addBeforeLast extra items =
    case items of
        first :: last :: [] ->
            [ first, extra, last ]

        first :: rest ->
            first :: addBeforeLast extra rest

        [] ->
            []
