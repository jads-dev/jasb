module Util.Html exposing (..)

import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Url.Builder


blankA : String -> List String -> List (Html msg) -> Html msg
blankA origin path content =
    Html.a [ Url.Builder.crossOrigin origin path [] |> HtmlA.href ]
        (content ++ [ Html.span [ HtmlA.class "external" ] [ Icon.externalLinkAlt |> Icon.viewIcon ] ])
