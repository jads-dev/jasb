module JoeBets.Gacha.Balance exposing
    ( Balance
    , decoder
    , empty
    )

import JoeBets.Gacha.Balance.Guarantees exposing (..)
import JoeBets.Gacha.Balance.Rolls exposing (..)
import JoeBets.Gacha.Balance.Scrap exposing (..)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD


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
