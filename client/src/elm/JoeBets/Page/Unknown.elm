module JoeBets.Page.Unknown exposing
    ( init
    , load
    , view
    )

import Html exposing (Html)
import JoeBets.Page exposing (Page)
import JoeBets.Page.Unknown.Model exposing (Model, Msg(..))


type alias Parent a =
    { a | unknown : Model }


init : Model
init =
    { path = "" }


load : String -> Parent a -> ( Parent a, Cmd msg )
load path ({ unknown } as model) =
    ( { model | unknown = { unknown | path = path } }, Cmd.none )


view : Parent a -> Page msg
view { unknown } =
    { title = "Page Not Found"
    , id = "unknown"
    , body = [ Html.text "Unknown Page “", unknown.path |> Html.text, Html.text "”." ]
    }
