module JoeBets.Page exposing (Page)

import Html exposing (Html)


type alias Page msg =
    { title : String
    , id : String
    , body : List (Html msg)
    }
