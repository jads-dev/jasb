module JoeBets.Page.Edit.Validator exposing
    ( Validator
    , all
    , andThen
    , fromPredicate
    , ifValid
    , list
    , map
    , valid
    , view
    , whenValid
    )

import Html exposing (Html)
import Html.Attributes as HtmlA


type alias Validator model =
    model -> List String


fromPredicate : String -> (model -> Bool) -> Validator model
fromPredicate description predicate model =
    if predicate model then
        [ description ]

    else
        []


all : List (Validator model) -> Validator model
all validators model =
    validators |> List.concatMap (\v -> v model)


andThen : Validator model -> Validator model -> Validator model
andThen b a model =
    let
        errors =
            a model
    in
    if List.isEmpty errors then
        b model

    else
        errors


view : Validator model -> model -> Html msg
view validator model =
    let
        errors =
            validator model
    in
    if errors |> List.isEmpty |> not then
        errors |> List.map (Html.text >> List.singleton >> Html.li []) |> Html.ul [ HtmlA.class "errors" ]

    else
        Html.text ""


valid : Validator model -> model -> Bool
valid validator model =
    validator model |> List.isEmpty


list : Validator model -> Validator (List model)
list validator model =
    model |> List.concatMap validator


map : (b -> a) -> Validator a -> Validator b
map f a model =
    model |> f |> a


whenValid : Validator model -> model -> a -> Maybe a
whenValid validator model value =
    if valid validator model then
        Just value

    else
        Nothing


ifValid : Validator model -> model -> Maybe model
ifValid validator model =
    whenValid validator model model
