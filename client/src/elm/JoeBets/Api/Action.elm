module JoeBets.Api.Action exposing
    ( ActionState
    , doAction
    , doActionIconButton
    , failAction
    , handleActionDone
    , handleActionResult
    , ifNotWorking
    , initAction
    , isFailed
    , isNeutral
    , isWorking
    , orSpinner
    , toMaybeError
    , viewAction
    , viewActionError
    )

import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Api.Error exposing (..)
import JoeBets.Api.Model exposing (..)
import Material.IconButton as IconButton
import Material.Progress as Progress


type ActionState
    = Neutral
    | Working
    | Failed Error


initAction : ActionState
initAction =
    Neutral


doAction : ActionState -> Cmd msg -> ( ActionState, Cmd msg )
doAction state request =
    case state of
        Working ->
            ( state, Cmd.none )

        _ ->
            ( Working, request )


failAction : Error -> ActionState
failAction =
    Failed


isFailed : ActionState -> Bool
isFailed state =
    case state of
        Failed _ ->
            True

        _ ->
            False


isNeutral : ActionState -> Bool
isNeutral state =
    state == Neutral


isWorking : ActionState -> Bool
isWorking state =
    state == Working


toMaybeError : ActionState -> Maybe Error
toMaybeError state =
    case state of
        Failed error ->
            Just error

        _ ->
            Nothing


handleActionResult : Response value -> ActionState -> ( Maybe value, ActionState )
handleActionResult response _ =
    case response of
        Ok value ->
            ( Just value, Neutral )

        Err error ->
            ( Nothing, Failed error )


handleActionDone : Response () -> ActionState -> ActionState
handleActionDone response state =
    handleActionResult response state |> Tuple.second


viewAction : List (Html msg) -> ActionState -> List (Html msg)
viewAction default state =
    case state of
        Neutral ->
            default

        Working ->
            [ Html.div [ HtmlA.class "loading" ]
                [ Progress.circular
                    |> Progress.attrs [ HtmlA.class "progress" ]
                    |> Progress.view
                ]
            ]

        Failed error ->
            [ viewError error ]


viewActionError : List (Html msg) -> ActionState -> List (Html msg)
viewActionError default state =
    case state of
        Neutral ->
            default

        Working ->
            default

        Failed error ->
            [ viewError error ]


orSpinner : ActionState -> Html msg -> Html msg
orSpinner state icon =
    case state of
        Neutral ->
            icon

        Working ->
            Progress.circular
                |> Progress.attrs [ HtmlA.class "progress" ]
                |> Progress.view

        Failed _ ->
            icon


ifNotWorking : ActionState -> Maybe msg -> Maybe msg
ifNotWorking state action =
    if isWorking state then
        Nothing

    else
        action


doActionIconButton : ActionState -> Html msg -> String -> Maybe msg -> List (Html msg)
doActionIconButton state icon title action =
    let
        error =
            case state of
                Failed httpError ->
                    [ viewError httpError ]

                _ ->
                    []
    in
    (IconButton.icon (orSpinner state icon) title
        |> IconButton.button (ifNotWorking state action)
        |> IconButton.view
    )
        :: error
