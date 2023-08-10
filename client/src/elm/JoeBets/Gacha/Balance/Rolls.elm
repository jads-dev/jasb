module JoeBets.Gacha.Balance.Rolls exposing
    ( Rolls
    , compareRolls
    , encodeRolls
    , rawRollIcon
    , rollDescription
    , rollIcon
    , rollName
    , rollWithGuaranteeIcon
    , rollsDecoder
    , rollsFromInt
    , rollsToString
    , viewRolls
    )

import FontAwesome as Icon exposing (Icon)
import FontAwesome.Layering as Icon
import FontAwesome.Solid as Icon
import FontAwesome.Transforms as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Gacha.Balance.Guarantees as Balance
import Json.Decode as JsonD
import Json.Encode as JsonE


type Rolls
    = Rolls Int


rawRollIcon : Icon Icon.WithoutId
rawRollIcon =
    Icon.diceD20


rollIcon : Html msg
rollIcon =
    rawRollIcon |> Icon.view


rollWithGuaranteeIcon : Html msg
rollWithGuaranteeIcon =
    Icon.layers []
        [ rawRollIcon
            |> Icon.transform
                [ Icon.shrink 3
                , Icon.up 3
                , Icon.left 3
                ]
            |> Icon.view
        , Balance.rawGuaranteeIcon
            |> Icon.transform
                [ Icon.shrink 6
                , Icon.down 4
                , Icon.right 4
                ]
            |> Icon.view
        ]


rollName : String
rollName =
    "Rolls"


rollDescription : String
rollDescription =
    "Get them for winning bets, spent to obtain cards randomly or forge cards."


rollsFromInt : Int -> Rolls
rollsFromInt =
    Rolls


rollsToString : Rolls -> String
rollsToString (Rolls rolls) =
    rolls |> String.fromInt


viewRolls : Rolls -> Html msg
viewRolls (Rolls rolls) =
    Html.span
        [ HtmlA.class "rolls"
        , rollName ++ ". " ++ rollDescription |> HtmlA.title
        ]
        [ rollIcon, rolls |> String.fromInt |> Html.text ]


rollsDecoder : JsonD.Decoder Rolls
rollsDecoder =
    JsonD.int |> JsonD.map Rolls


encodeRolls : Rolls -> JsonE.Value
encodeRolls (Rolls rolls) =
    rolls |> JsonE.int


compareRolls : Rolls -> Rolls -> Order
compareRolls (Rolls a) (Rolls b) =
    compare a b
