module JoeBets.Page.Problem exposing
    ( init
    , load
    , view
    )

import Html exposing (Html)
import JoeBets.Page exposing (Page)
import JoeBets.Page.Problem.Model exposing (..)


type alias Parent a =
    { a | problem : Model }


init : Model
init =
    Loading


load : String -> Parent a -> ( Parent a, Cmd msg )
load path ({ problem } as model) =
    ( { model | problem = UnknownPage { path = path } }, Cmd.none )


view : Parent a -> Page msg
view { problem } =
    let
        ( title, body ) =
            case problem of
                Loading ->
                    ( "There was a problem...", [] )

                UnknownPage { path } ->
                    ( "Page Not Found", [ Html.text "Unknown Page “", path |> Html.text, Html.text "”." ] )

                MustBeLoggedIn { path } ->
                    ( "Unauthorized", [ Html.text "Please log in to view “", path |> Html.text, Html.text "”." ] )
    in
    { title = title
    , id = "problem"
    , body = body
    }
