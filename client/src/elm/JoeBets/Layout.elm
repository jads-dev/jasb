module JoeBets.Layout exposing
    ( Layout(..)
    , all
    , decoder
    , encode
    , fromString
    , selectItem
    , toClass
    , toString
    )

import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html
import Html.Attributes as HtmlA
import Json.Decode as JsonD
import Json.Encode as JsonE
import Material.Select as Select
import Util.Json.Decode as JsonD


type Layout
    = Auto
    | Wide
    | Narrow


all : List Layout
all =
    [ Auto, Wide, Narrow ]


toString : Layout -> String
toString layout =
    case layout of
        Auto ->
            "auto"

        Wide ->
            "wide"

        Narrow ->
            "narrow"


toClass : Layout -> Html.Attribute msg
toClass layout =
    (toString layout ++ "-layout") |> HtmlA.class


encode : Layout -> JsonE.Value
encode =
    toString >> JsonE.string


fromString : String -> Maybe Layout
fromString string =
    case string of
        "wide" ->
            Just Wide

        "narrow" ->
            Just Narrow

        "auto" ->
            Just Auto

        _ ->
            Nothing


decoder : JsonD.Decoder Layout
decoder =
    let
        fromStringJson string =
            string
                |> fromString
                |> Maybe.map JsonD.succeed
                |> Maybe.withDefault (JsonD.unknownValue "layout" string)
    in
    JsonD.string |> JsonD.andThen fromStringJson


selectItem : Layout -> Select.ItemModel Layout msg
selectItem layout =
    let
        ( icon, name, description ) =
            case layout of
                Auto ->
                    ( Icon.rulerCombined, "Auto", "Automatically choose layout based on screen size." )

                Wide ->
                    ( Icon.expandAlt, "Wide", "Display all the detail available." )

                Narrow ->
                    ( Icon.compressAlt, "Narrow", "Remove some details to help fit smaller screens." )
    in
    { id = layout
    , icon = icon |> Icon.view |> Just
    , primary = [ Html.text name ]
    , secondary = [ Html.text "(", Html.text description, Html.text ")" ] |> Just
    , meta = Nothing
    }
