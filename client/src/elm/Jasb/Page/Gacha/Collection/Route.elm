module Jasb.Page.Gacha.Collection.Route exposing
    ( Route(..)
    , routeParser
    , routeToListOfStrings
    )

import Jasb.Gacha.Banner as Banner
import Jasb.Gacha.Card as Card
import Url.Parser as Parser exposing ((</>), Parser)


type Route
    = Overview
    | All
    | Banner Banner.Id
    | Card Banner.Id Card.Id


routeToListOfStrings : Route -> List String
routeToListOfStrings route =
    case route of
        Overview ->
            []

        All ->
            [ "all" ]

        Banner bannerId ->
            [ Banner.idToString bannerId ]

        Card bannerId cardId ->
            [ Banner.idToString bannerId
            , "card"
            , cardId |> Card.idToInt |> String.fromInt
            ]


routeParser : Parser (Route -> a) a
routeParser =
    Parser.oneOf
        [ Parser.s "all" |> Parser.map All
        , Banner.idParser </> Parser.s "card" </> Card.idParser |> Parser.map Card
        , Banner.idParser |> Parser.map Banner
        , Parser.top |> Parser.map Overview
        ]
