module Util.AssocList exposing
    ( filterJust
    , findIndexOfKey
    , findKeyAtIndex
    , fromListWithDerivedKey
    , indexedMap
    , keySet
    , sortBy
    , sortWith
    )

import AssocList
import EverySet exposing (EverySet)
import Util.Order as Order


indexedMap : (Int -> key -> value -> value) -> AssocList.Dict key value -> AssocList.Dict key value
indexedMap func assocList =
    let
        lastIndex =
            AssocList.size assocList - 1

        step key value ( index, results ) =
            ( index - 1, AssocList.insert key (func index key value) results )

        ( _, result ) =
            AssocList.foldr step ( lastIndex, AssocList.empty ) assocList
    in
    result


fromListWithDerivedKey : (value -> key) -> List value -> AssocList.Dict key value
fromListWithDerivedKey deriveKey =
    let
        pair value =
            ( deriveKey value, value )
    in
    List.map pair >> AssocList.fromList


findIndexOfKey : k -> AssocList.Dict k v -> Maybe Int
findIndexOfKey key assocList =
    let
        internal index keys =
            case keys of
                first :: rest ->
                    if first == key then
                        Just index

                    else
                        internal (index + 1) rest

                [] ->
                    Nothing
    in
    assocList |> AssocList.keys |> internal 0


findKeyAtIndex : Int -> AssocList.Dict k v -> Maybe k
findKeyAtIndex index assocList =
    let
        internal drop keys =
            case keys of
                first :: rest ->
                    if drop < 1 then
                        Just first

                    else
                        internal (drop - 1) rest

                [] ->
                    Nothing
    in
    assocList |> AssocList.keys |> internal index


filterJust : AssocList.Dict key (Maybe value) -> AssocList.Dict key value
filterJust =
    filterMap (\k -> Maybe.map (Tuple.pair k))


filterMap : (key -> value -> Maybe ( toKey, toValue )) -> AssocList.Dict key value -> AssocList.Dict toKey toValue
filterMap op =
    let
        step key value results =
            case op key value of
                Just ( k, v ) ->
                    AssocList.insert k v results

                Nothing ->
                    results
    in
    AssocList.foldr step AssocList.empty


keySet : AssocList.Dict id value -> EverySet id
keySet =
    AssocList.foldr (\k _ -> EverySet.insert k) EverySet.empty


sortBy : (key -> value -> comparable) -> AssocList.Dict key value -> AssocList.Dict key value
sortBy property =
    let
        comparePair ( k1, v1 ) ( k2, v2 ) =
            let
                p1 =
                    property k1 v1

                p2 =
                    property k2 v2
            in
            compare p1 p2
    in
    sortWith comparePair


sortWith : (( key, value ) -> ( key, value ) -> Order) -> AssocList.Dict key value -> AssocList.Dict key value
sortWith comparePair =
    AssocList.toList >> List.sortWith (\a b -> comparePair a b |> Order.reverse) >> AssocList.fromList
