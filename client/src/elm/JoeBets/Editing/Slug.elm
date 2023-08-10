module JoeBets.Editing.Slug exposing
    ( Slug(..)
    , init
    , resolve
    , set
    , validator
    , view
    )

import Html exposing (Html)
import JoeBets.Editing.Validator as Validator exposing (Validator)
import List.Extra as List
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
            name |> Maybe.map (Url.slugify >> idFromString >> Manual) |> Maybe.withDefault Auto


view : (String -> id) -> (id -> String) -> Maybe (String -> msg) -> String -> Slug id -> Html msg
view idFromString idToString changeId name slug =
    let
        value =
            resolve idFromString name slug

        ( supportingText, action ) =
            case slug of
                Locked _ ->
                    ( "Can't change the id/slug after first save.", Nothing )

                _ ->
                    ( "Slugs must be unique, and are limited in length and character set to be used in URLs."
                    , changeId
                    )
    in
    TextField.outlined "Id"
        action
        (idToString value)
        |> TextField.supportingText supportingText
        |> TextField.view


validator : (String -> id) -> (value -> ( Slug id, String )) -> List value -> Validator value
validator idFromString getSlugAndName values =
    let
        resolveFromTuple ( slug, name ) =
            resolve idFromString name slug

        resolvedIds =
            values |> List.map (getSlugAndName >> resolveFromTuple)

        isNotUnique value =
            let
                targetId =
                    value |> getSlugAndName |> resolveFromTuple
            in
            List.count ((==) targetId) resolvedIds > 1
    in
    Validator.fromPredicate "Slug must be unqiue." isNotUnique
