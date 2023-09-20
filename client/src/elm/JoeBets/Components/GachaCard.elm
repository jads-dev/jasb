module JoeBets.Components.GachaCard exposing
    ( banner
    , description
    , image
    , interactive
    , layout
    , name
    , qualities
    , rarity
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
        >> String.padLeft 10 '0'
        >> HtmlA.attribute "serial-number"


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


view : List (Html.Attribute msg) -> Html msg
view attrs =
    Html.node "gacha-card" attrs []


layout : Card.Layout -> Html.Attribute msg
layout =
    Card.layoutToString >> HtmlA.attribute "layout"
