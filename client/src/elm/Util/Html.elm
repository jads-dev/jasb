module Util.Html exposing
    ( blankA
    , summaryMarker
    )

import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Svg.Attributes as SvgA
import Url.Builder


blankA : String -> List String -> List (Html msg) -> Html msg
blankA origin path content =
    Html.a [ Url.Builder.crossOrigin origin path [] |> HtmlA.href, HtmlA.target "_blank", HtmlA.rel "noopener" ]
        (content ++ [ Html.span [ HtmlA.class "external" ] [ Icon.externalLinkAlt |> Icon.view ] ])


summaryMarker : Html msg
summaryMarker =
    Html.div [ HtmlA.class "marker" ]
        [ Icon.chevronUp |> Icon.styled [ SvgA.class "up" ] |> Icon.view
        , Icon.chevronDown |> Icon.styled [ SvgA.class "down" ] |> Icon.view
        ]
