module JoeBets.Components.GachaCard exposing
    ( banner
    , description
    , image
    , interactive
    , issueNumber
    , layout
    , name
    , qualities
    , rarity
    , retired
    , sample
    , serialNumber
    , view
    )

import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Gacha.Banner as Banner
import JoeBets.Gacha.Card as Card
import JoeBets.Gacha.Card.Layout as Card
import JoeBets.Gacha.Quality as Quality
import JoeBets.Gacha.Rarity as Rarity


name : String -> Html.Attribute msg
name =
    HtmlA.attribute "name"


serialNumber : Card.Id -> Html.Attribute msg
serialNumber =
    Card.idToInt
        >> String.fromInt
        >> HtmlA.attribute "serial-number"


issueNumber : Int -> Html.Attribute msg
issueNumber =
    String.fromInt >> HtmlA.attribute "issue-number"


description : String -> Html.Attribute msg
description =
    HtmlA.attribute "description"


image : String -> Html.Attribute msg
image =
    HtmlA.attribute "image"


rarity : Rarity.Id -> Html.Attribute msg
rarity =
    Rarity.idToString >> HtmlA.attribute "rarity"


banner : Banner.Id -> Html.Attribute msg
banner =
    Banner.idToString >> HtmlA.attribute "banner"


qualities : List Quality.Id -> Html.Attribute msg
qualities =
    List.map Quality.idToString
        >> String.join " "
        >> HtmlA.attribute "qualities"


interactive : Html.Attribute msg
interactive =
    HtmlA.attribute "interactive" ""


sample : Html.Attribute msg
sample =
    HtmlA.attribute "sample" ""


retired : Html.Attribute msg
retired =
    HtmlA.attribute "retired" ""


view : List (Html.Attribute msg) -> Html msg
view attrs =
    Html.node "gacha-card" attrs []


layout : Card.Layout -> Html.Attribute msg
layout =
    Card.layoutToString >> HtmlA.attribute "layout"
