module Util.List exposing
    ( addBeforeLast
    , filterJust
    , fromNonEmpty
    , insertAt
    , moveTo
    , stepRange
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
    let
        internal soFar itemsLeft =
            case itemsLeft of
                first :: last :: [] ->
                    soFar ++ [ first, extra, last ]

                first :: rest ->
                    internal (first :: soFar) rest

                [] ->
                    soFar
    in
    internal [] items


stepRange : Int -> Int -> Int -> List Int
stepRange start step stop =
    let
        internal current values =
            if current <= stop then
                internal (current + step) (current :: values)

            else
                values
    in
    internal start [] |> reverse
