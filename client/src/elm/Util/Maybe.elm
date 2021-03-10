module Util.Maybe exposing
    ( or
    , toList
    , when
    )


toList : Maybe a -> List a
toList maybe =
    case maybe of
        Just a ->
            [ a ]

        Nothing ->
            []


when : Bool -> a -> Maybe a
when condition value =
    if condition then
        Just value

    else
        Nothing


or : Maybe a -> Maybe a -> Maybe a
or b a =
    case a of
        Just _ ->
            a

        Nothing ->
            b
