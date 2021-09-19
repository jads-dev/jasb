module JoeBets.Editing.Slug exposing
    ( Slug(..)
    , init
    , resolve
    , set
    , view
    )

import Html exposing (Html)
import Html.Attributes as HtmlA
import Material.TextField as TextField
import Util.Url as Url


type Slug id
    = Locked id
    | Manual id
    | Auto


init : Slug id
init =
    Auto


resolve : (String -> id) -> String -> Slug id -> id
resolve idFromString name slug =
    case slug of
        Locked lockedId ->
            lockedId

        Manual manualId ->
            manualId

        Auto ->
            name |> Url.slugify |> idFromString


set : (String -> id) -> Maybe String -> Slug id -> Slug id
set idFromString name slug =
    case slug of
        Locked _ ->
            slug

        _ ->
            name |> Maybe.map (idFromString >> Manual) |> Maybe.withDefault Auto


view : (String -> id) -> (id -> String) -> (String -> msg) -> String -> Slug id -> Html msg
view idFromString idToString changeId name slug =
    let
        value =
            resolve idFromString name slug

        ( title, action ) =
            case slug of
                Locked _ ->
                    ( [ HtmlA.title "Can't change the id/slug after first save." ], Nothing )

                _ ->
                    ( [], changeId |> Just )
    in
    TextField.viewWithAttrs
        "Id"
        TextField.Text
        (idToString value)
        action
        (HtmlA.attribute "outlined" "" :: title)
