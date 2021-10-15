module Util.Maybe exposing
    ( alsoOnlyIf
    , ifDifferent
    , ifFalse
    , ifTrue
    , or
    , toList
    , when
    , whenNot
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


whenNot : Bool -> a -> Maybe a
whenNot =
    not >> when


alsoOnlyIf : Bool -> Maybe a -> Maybe a
alsoOnlyIf condition value =
    if condition then
        value

    else
        Nothing


ifTrue : (a -> Bool) -> a -> Maybe a
ifTrue predicate value =
    if predicate value then
        Just value

    else
        Nothing


ifFalse : (a -> Bool) -> a -> Maybe a
ifFalse predicate value =
    if predicate value then
        Nothing

    else
        Just value


or : Maybe a -> Maybe a -> Maybe a
or b a =
    case a of
        Just _ ->
            a

        Nothing ->
            b


ifDifferent : value -> value -> Maybe value
ifDifferent old new =
    if new == old then
        Nothing

    else
        Just new
