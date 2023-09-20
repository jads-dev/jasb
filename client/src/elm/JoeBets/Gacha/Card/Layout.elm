module JoeBets.Gacha.Card.Layout exposing
    ( Layout(..)
    , describeLayout
    , encodeLayout
    , layoutDecoder
    , layoutFromString
    , layoutSelector
    , layoutToString
    , layouts
    )

import Html exposing (Html)
import Json.Decode as JsonD
import Json.Encode as JsonE
import Material.Select as Select
import Util.Maybe as Maybe


type Layout
    = Normal
    | FullImage
    | LandscapeFullImage


describeLayout : Layout -> { name : String }
describeLayout layout =
    case layout of
        Normal ->
            { name = "Normal" }

        FullImage ->
            { name = "Full Image" }

        LandscapeFullImage ->
            { name = "Landscape Full Image" }


layouts : List Layout
layouts =
    [ Normal, FullImage, LandscapeFullImage ]


layoutToString : Layout -> String
layoutToString layout =
    case layout of
        Normal ->
            "normal"

        FullImage ->
            "full-image"

        LandscapeFullImage ->
            "landscape-full-image"


layoutFromString : String -> Maybe Layout
layoutFromString string =
    case string of
        "normal" ->
            Just Normal

        "full-image" ->
            Just FullImage

        "landscape-full-image" ->
            Just LandscapeFullImage

        _ ->
            Nothing


encodeLayout : Layout -> JsonE.Value
encodeLayout layout =
    let
        string =
            case layout of
                Normal ->
                    "Normal"

                FullImage ->
                    "FullImage"

                LandscapeFullImage ->
                    "LandscapeFullImage"
    in
    JsonE.string string


layoutDecoder : JsonD.Decoder Layout
layoutDecoder =
    let
        fromString string =
            case string of
                "Normal" ->
                    JsonD.succeed Normal

                "FullImage" ->
                    JsonD.succeed FullImage

                "LandscapeFullImage" ->
                    JsonD.succeed LandscapeFullImage

                _ ->
                    "Unknown Card Layout “" ++ string ++ "”" |> JsonD.fail
    in
    JsonD.string |> JsonD.andThen fromString


layoutSelector : Maybe (Maybe Layout -> msg) -> Maybe Layout -> Html msg
layoutSelector select selected =
    let
        option layout =
            let
                { name } =
                    describeLayout layout
            in
            Select.option name (Just layout == selected) (layoutToString layout)

        fromString : (Maybe Layout -> msg) -> (String -> msg)
        fromString f =
            layoutFromString >> f
    in
    layouts
        |> List.map option
        |> Select.outlined "Layout" (select |> Maybe.map fromString)
        |> Select.supportingText "The layout of the card." True
        |> Select.error ("You must select a layout." |> Maybe.when (selected == Nothing))
        |> Select.required True
        |> Select.view
