module JoeBets.Filtering exposing
    ( Criteria(..)
    , Selection
    , combine
    , toPredicate
    , viewFilters
    )

import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Material.Chips as Chips


type Criteria item
    = Include (item -> Bool)
    | Exclude (item -> Bool)


type alias Selection item =
    { include : item -> Bool
    , exclude : item -> Bool
    }


combine : List (Criteria item) -> Selection item
combine criteria =
    let
        fold current selection =
            case current of
                Include predicate ->
                    { selection | include = predicate :: selection.include }

                Exclude predicate ->
                    { selection | exclude = predicate :: selection.exclude }

        listSelections =
            List.foldl fold { include = [], exclude = [] } criteria
    in
    { include = \i -> List.any (\f -> f i) listSelections.include
    , exclude = \i -> List.any (\f -> f i) listSelections.exclude
    }


toPredicate : Selection item -> item -> Bool
toPredicate { include, exclude } item =
    include item && not (exclude item)


viewFilters : String -> Int -> Int -> List (Html msg) -> Html msg
viewFilters name totalCount shownCount filters =
    let
        title =
            [ Icon.view Icon.filter
            , Html.text " Filter "
            , Html.text name
            , Html.text " ("
            , shownCount |> String.fromInt |> Html.text
            , Html.text "/"
            , totalCount |> String.fromInt |> Html.text
            , Html.text " shown)."
            ]
    in
    Html.div [ HtmlA.class "filters" ] [ Html.span [] title, filters |> Chips.set [] ]
