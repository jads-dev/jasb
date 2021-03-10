module Util.AssocList exposing
    ( filterJust
    , findIndexOfKey
    , findKeyAtIndex
    )

import AssocList


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
