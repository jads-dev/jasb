module Jasb.Gacha.Balance exposing
    ( Balance
    , Value
    , decoder
    , empty
    , valueDecoder
    )

import Jasb.Gacha.Balance.Guarantees exposing (..)
import Jasb.Gacha.Balance.Rolls exposing (..)
import Jasb.Gacha.Balance.Scrap exposing (..)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Util.Json.Decode as JsonD


type alias Balance =
    { rolls : Rolls
    , guarantees : Guarantees
    , scrap : Scrap
    }


empty : Balance
empty =
    Balance (rollsFromInt 0) (guaranteesFromInt 0) (scrapFromInt 0)


decoder : JsonD.Decoder Balance
decoder =
    JsonD.succeed Balance
        |> JsonD.required "rolls" rollsDecoder
        |> JsonD.required "guarantees" guaranteesDecoder
        |> JsonD.required "scrap" scrapDecoder


type alias Value =
    { rolls : Maybe Rolls
    , guarantees : Maybe Guarantees
    , scrap : Maybe Scrap
    }


valueDecoder : JsonD.Decoder Value
valueDecoder =
    JsonD.succeed Value
        |> JsonD.optionalAsMaybe "rolls" rollsDecoder
        |> JsonD.optionalAsMaybe "guarantees" guaranteesDecoder
        |> JsonD.optionalAsMaybe "scrap" scrapDecoder
