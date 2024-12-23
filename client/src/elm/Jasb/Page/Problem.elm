module Jasb.Page.Problem exposing
    ( init
    , load
    , onAuthChange
    , view
    )

import Browser.Navigation as Browser
import Html
import Jasb.Page exposing (Page)
import Jasb.Page.Problem.Model exposing (..)


type alias Parent a =
    { a
        | navigationKey : Browser.Key
        , problem : Model
    }


init : Model
init =
    Loading


onAuthChange : Parent a -> ( Parent a, Cmd msg )
onAuthChange ({ navigationKey, problem } as parent) =
    case problem of
        MustBeLoggedIn { path } ->
            ( parent, Browser.pushUrl navigationKey path )

        _ ->
            ( parent, Cmd.none )


load : String -> Parent a -> ( Parent a, Cmd msg )
load path model =
    ( { model | problem = UnknownPage { path = path } }, Cmd.none )


view : String -> Parent a -> Page msg
view _ { problem } =
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
