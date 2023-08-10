module JoeBets.Overlay exposing
    ( view
    , viewLevel
    )

import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Events as HtmlE


view : msg -> List (Html msg) -> Html msg
view =
    viewLevel 0


{-| Sometimes we can't avoid nesting overlays, avoid whenever possible, but
using this can deconflict them.
-}
viewLevel : Int -> msg -> List (Html msg) -> Html msg
viewLevel level close content =
    Html.div
        [ HtmlA.class "overlay"
        , HtmlA.attribute "style" ("--overlay-level: " ++ String.fromInt level)
        ]
        [ Html.div [ HtmlA.class "background", close |> HtmlE.onClick ] []
        , Html.div [ HtmlA.class "foreground" ] content
        ]
