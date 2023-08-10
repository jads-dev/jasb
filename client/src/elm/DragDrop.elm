module DragDrop exposing
    ( Model
    , Msg
    , draggable
    , droppable
    , getDragId
    , getDropId
    , init
    , update
    )

{-| Based on <https://github.com/norpan/elm-html5-drag-drop/tree/3.1.4>,
streamlined for this use case.
-}

import Html
import Html.Attributes as HtmlA
import Html.Events as HtmlE
import Json.Decode as JsonD


type Model dragId dropId
    = NotDragging
    | Dragging dragId
    | DraggedOver dragId dropId


init : Model dragId dropId
init =
    NotDragging


type Msg dragId dropId
    = DragStart dragId
    | DragEnd
    | DragEnter dropId
    | DragLeave dropId
    | Drop dropId
    | DragOver


update : Msg dragId dropId -> Model dragId dropId -> ( Model dragId dropId, Maybe ( dragId, dropId ) )
update msg model =
    case ( msg, model ) of
        ( DragStart dragging, _ ) ->
            ( Dragging dragging, Nothing )

        ( DragEnd, _ ) ->
            ( NotDragging, Nothing )

        ( DragEnter draggedOver, Dragging dragging ) ->
            ( DraggedOver dragging draggedOver, Nothing )

        ( DragEnter draggedOver, DraggedOver dragging _ ) ->
            ( DraggedOver dragging draggedOver, Nothing )

        ( DragLeave left, DraggedOver dragging currentlyOver ) ->
            if left == currentlyOver then
                ( Dragging dragging, Nothing )

            else
                ( model, Nothing )

        ( Drop droppedOn, Dragging dragging ) ->
            ( NotDragging, Just ( dragging, droppedOn ) )

        ( Drop droppedOn, DraggedOver dragging _ ) ->
            ( NotDragging, Just ( dragging, droppedOn ) )

        _ ->
            ( model, Nothing )


draggable : (Msg dragId dropId -> msg) -> dragId -> List (Html.Attribute msg)
draggable wrap drag =
    [ HtmlA.draggable "true"
    , DragStart drag |> wrap |> onPreventDefault "dragstart" { preventDefault = False }
    , DragEnd |> wrap |> onPreventDefault "dragend" { preventDefault = False }
    ]


droppable : (Msg dragId dropId -> msg) -> dropId -> List (Html.Attribute msg)
droppable wrap dropId =
    [ DragEnter dropId |> wrap |> onPreventDefault "dragenter" { preventDefault = True }
    , DragLeave dropId |> wrap |> onPreventDefault "dragleave" { preventDefault = True }
    , DragOver |> wrap |> onPreventDefault "dragover" { preventDefault = True }
    , Drop dropId |> wrap |> onPreventDefault "drop" { preventDefault = True }
    ]


getDragId : Model dragId dropId -> Maybe dragId
getDragId model =
    case model of
        NotDragging ->
            Nothing

        Dragging dragId ->
            Just dragId

        DraggedOver dragId _ ->
            Just dragId


getDropId : Model dragId dropId -> Maybe dropId
getDropId model =
    case model of
        NotDragging ->
            Nothing

        Dragging _ ->
            Nothing

        DraggedOver _ dropId ->
            Just dropId


onPreventDefault : String -> { preventDefault : Bool } -> msg -> Html.Attribute msg
onPreventDefault name { preventDefault } msg =
    { message = msg
    , stopPropagation = True
    , preventDefault = preventDefault
    }
        |> JsonD.succeed
        |> HtmlE.custom name
