module Util.Html exposing
    ( blankA
    , imgFallback
    )

import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html as Html exposing (Html)
import Html.Attributes as HtmlA
import Url.Builder
import Util.Maybe as Maybe


blankA : String -> List String -> List (Html msg) -> Html msg
blankA origin path content =
    Html.a [ Url.Builder.crossOrigin origin path [] |> HtmlA.href, HtmlA.target "_blank", HtmlA.rel "noopener" ]
        (content ++ [ Html.span [ HtmlA.class "external" ] [ Icon.externalLinkAlt |> Icon.view ] ])


imgFallback : { src : String, alt : String } -> { src : String, alt : Maybe String } -> List (Html.Attribute msg) -> Html msg
imgFallback image fallback attrs =
    let
        allAttrs =
            List.concat
                [ [ HtmlA.attribute "src" image.src
                  , HtmlA.attribute "alt" image.alt
                  , HtmlA.attribute "fallback-src" fallback.src
                  ]
                , fallback.alt |> Maybe.map (HtmlA.attribute "fallback-alt") |> Maybe.toList
                , attrs
                ]
    in
    Html.node "img-fallback" allAttrs []
