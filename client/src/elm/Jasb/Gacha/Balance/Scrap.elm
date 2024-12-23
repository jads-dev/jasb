module Jasb.Gacha.Balance.Scrap exposing
    ( Scrap
    , compareScrap
    , encodeScrap
    , scrapDecoder
    , scrapDescription
    , scrapFromInt
    , scrapIcon
    , scrapName
    , scrapToString
    , viewScrap
    )

import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Jasb.Rules as Rules
import Jasb.Sentiment as Sentiment exposing (Sentiment)
import Json.Decode as JsonD
import Json.Encode as JsonE


type Scrap
    = Scrap Int


scrapIcon : Html msg
scrapIcon =
    Icon.cubes |> Icon.view


scrapName : String
scrapName =
    "Scrap"


scrapDescription : String
scrapDescription =
    "Get it for recycling cards and losing bets, gets exchanged for rolls when you get "
        ++ String.fromInt Rules.scrapPerRoll
        ++ "."


scrapFromInt : Int -> Scrap
scrapFromInt =
    Scrap


scrapToString : Scrap -> String
scrapToString (Scrap scrap) =
    scrap |> String.fromInt


viewScrap : Sentiment -> Scrap -> Html msg
viewScrap sentiment (Scrap scrap) =
    Html.span
        [ HtmlA.class "scrap"
        , scrapName ++ ". " ++ scrapDescription |> HtmlA.title
        ]
        [ scrapIcon, Sentiment.viewValue sentiment scrap ]


scrapDecoder : JsonD.Decoder Scrap
scrapDecoder =
    JsonD.int |> JsonD.map Scrap


encodeScrap : Scrap -> JsonE.Value
encodeScrap (Scrap scrap) =
    scrap |> JsonE.int


compareScrap : Scrap -> Scrap -> Order
compareScrap (Scrap a) (Scrap b) =
    compare a b
