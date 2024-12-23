module Jasb.Page.Leaderboard.Route exposing
    ( Board(..)
    , boardFromListOfStrings
    , boardParser
    , boardToListOfStrings
    )

import Url.Parser as Url


type Board
    = NetWorth
    | Debt


boardToListOfStrings : Board -> List String
boardToListOfStrings board =
    case board of
        NetWorth ->
            []

        Debt ->
            [ "debt" ]


boardFromListOfStrings : List String -> Maybe Board
boardFromListOfStrings board =
    case board of
        [] ->
            Just NetWorth

        [ "net-worth" ] ->
            Just NetWorth

        [ "debt" ] ->
            Just Debt

        _ ->
            Nothing


boardParser : Url.Parser (Board -> a) a
boardParser =
    Url.oneOf
        [ Url.top |> Url.map NetWorth
        , Url.s "net-worth" |> Url.map NetWorth
        , Url.s "debt" |> Url.map Debt
        ]
