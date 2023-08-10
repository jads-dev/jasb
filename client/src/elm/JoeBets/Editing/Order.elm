module JoeBets.Editing.Order exposing
    ( simplifyAndSortBy
    , sortBy
    , validator
    )

import AssocList
import JoeBets.Editing.Validator as Validator exposing (Validator)
import List.Extra as List
import Util.AssocList as AssocList


nothingsLast : Maybe comparable -> Maybe comparable -> Order
nothingsLast maybeA maybeB =
    case maybeA of
        Just a ->
            case maybeB of
                Just b ->
                    compare a b

                Nothing ->
                    LT

        Nothing ->
            case maybeB of
                Just _ ->
                    GT

                Nothing ->
                    EQ


{-| Simplify orders (where valid numbers) to just 1-indexed counting, ordering
the AssocList by that count.
Values that are not valid numbers will come last.
Floating point numbers are allowed, which makes it easier to shift positions
(by adding/taking 1.5).
-}
simplifyAndSortBy : (value -> Maybe Float) -> (Int -> value -> value) -> AssocList.Dict key value -> AssocList.Dict key value
simplifyAndSortBy getOrder setOrder assocList =
    let
        simplifiedOrders =
            assocList
                |> AssocList.filterMap (\k -> getOrder >> Maybe.map (\v -> ( k, v )))
                |> AssocList.toList
                |> List.sortBy Tuple.second
                |> List.indexedMap (\o ( id, _ ) -> ( id, o + 1 ))
                |> AssocList.fromList

        replaceOrder key value =
            case simplifiedOrders |> AssocList.get key of
                Just newOrder ->
                    setOrder newOrder value

                Nothing ->
                    value
    in
    assocList
        |> AssocList.map replaceOrder
        |> sortBy getOrder


{-| Order the AssocList by the order values.
-}
sortBy : (value -> Maybe Float) -> AssocList.Dict key value -> AssocList.Dict key value
sortBy getOrder =
    let
        sorter ( _, v1 ) ( _, v2 ) =
            nothingsLast (getOrder v1) (getOrder v2)
    in
    AssocList.sortWith sorter


{-| Validator for order values.
-}
validator : (value -> Maybe Float) -> AssocList.Dict key value -> Validator value
validator getOrder items =
    let
        orders =
            items |> AssocList.values |> List.map getOrder

        isNotUnique v =
            List.count ((==) v) orders > 1

        isNotPositiveInt v =
            case v of
                Just int ->
                    int < 0

                Nothing ->
                    True
    in
    [ Validator.fromPredicate "Order must be a positive whole number." isNotPositiveInt
    , Validator.fromPredicate "Order must be unqiue." isNotUnique
    ]
        |> Validator.all
        |> Validator.map getOrder
