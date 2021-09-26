module Util.Html.Events exposing (onToggle)

import Html
import Html.Events as HtmlE
import Json.Decode as JsonD


onToggle : (Bool -> msg) -> Html.Attribute msg
onToggle =
    let
        decodeToggleEvent toMsg =
            JsonD.at [ "target", "open" ] JsonD.bool |> JsonD.map toMsg
    in
    decodeToggleEvent >> HtmlE.on "toggle"
