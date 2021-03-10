module Util.List exposing
    ( filterJust
    , insertAt
    , moveTo
    )

import List exposing (..)
import List.Extra exposing (..)


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
