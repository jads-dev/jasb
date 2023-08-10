module JoeBets.Gacha.Balance.Guarantees exposing
    ( Guarantees
    , compareGuarantees
    , encodeGuarantees
    , guaranteeDescription
    , guaranteeIcon
    , guaranteeName
    , guaranteesDecoder
    , guaranteesFromInt
    , guaranteesToString
    , rawGuaranteeIcon
    , viewGuarantees
    )

import FontAwesome as Icon exposing (Icon)
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Json.Decode as JsonD
import Json.Encode as JsonE


type Guarantees
    = Guarantees Int


rawGuaranteeIcon : Icon Icon.WithoutId
rawGuaranteeIcon =
    Icon.wandMagicSparkles


guaranteeIcon : Html msg
guaranteeIcon =
    rawGuaranteeIcon |> Icon.view


guaranteeName : String
guaranteeName =
    "Magic"


guaranteeDescription : String
guaranteeDescription =
    "Received for getting unlucky, can be spent to ensure a highest rarity card in a roll."


guaranteesFromInt : Int -> Guarantees
guaranteesFromInt =
    Guarantees


guaranteesToString : Guarantees -> String
guaranteesToString (Guarantees guarantees) =
    guarantees |> String.fromInt


viewGuarantees : Guarantees -> Html msg
viewGuarantees (Guarantees guarantees) =
    Html.span
        [ HtmlA.class "guarantees"
        , guaranteeName ++ ". " ++ guaranteeDescription |> HtmlA.title
        ]
        [ guaranteeIcon, guarantees |> String.fromInt |> Html.text ]


guaranteesDecoder : JsonD.Decoder Guarantees
guaranteesDecoder =
    JsonD.int |> JsonD.map Guarantees


encodeGuarantees : Guarantees -> JsonE.Value
encodeGuarantees (Guarantees guarantees) =
    guarantees |> JsonE.int


compareGuarantees : Guarantees -> Guarantees -> Order
compareGuarantees (Guarantees a) (Guarantees b) =
    compare a b
