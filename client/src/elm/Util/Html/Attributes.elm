module Util.Html.Attributes exposing
    ( customProperties
    , muted
    )

import Html
import Html.Attributes as HtmlA
import Json.Encode as JsonE


customProperties : List ( String, String ) -> Html.Attribute msg
customProperties =
    let
        fromKeyValue ( key, value ) =
            "--" ++ key ++ ": " ++ value
    in
    List.map fromKeyValue
        >> List.intersperse "; "
        >> String.concat
        >> HtmlA.attribute "style"


muted : Bool -> Html.Attribute msg
muted =
    JsonE.bool >> HtmlA.property "muted"
