module JoeBets.Bet.Editor.LockMoment.Editor exposing
    ( Editor
    , EditorMsg(..)
    , Item
    , SaveState(..)
    , itemFromLockMoment
    , updateEditor
    , viewEditor
    )

import AssocList
import EverySet
import FontAwesome as Icon
import FontAwesome.Attributes as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Events as HtmlE
import Html.Keyed as HtmlK
import Http
import JoeBets.Api as Api
import JoeBets.Bet.Editor.LockMoment exposing (..)
import JoeBets.Editing.Order as Order
import JoeBets.Editing.Slug as Slug exposing (Slug)
import JoeBets.Game.Id as Game
import JoeBets.Page.Edit.Validator as Validator exposing (Validator)
import JoeBets.Page.Feed.Model exposing (Msg(..))
import Json.Encode as JsonE
import List.Extra as List
import Material.Attributes as Material
import Material.Button as Button
import Material.IconButton as IconButton
import Material.TextField as TextField
import Task
import Time.DateTime as DateTime exposing (DateTime)
import Util.Json.Encode.Pipeline as JsonE
import Util.Maybe as Maybe
import Util.RemoteData as RemoteData


type alias EditorId =
    Int


type EditorMsg
    = ShowEditor
    | Add (Maybe DateTime)
    | SetSlug EditorId (Maybe String)
    | SetName EditorId String
    | SetOrder Bool EditorId String
    | Remove EditorId
    | CancelEdit
    | SaveEdit
    | SaveError Http.Error


type alias Item =
    { slug : Slug Id
    , name : String
    , order : String
    , bets : Int
    , version : Int
    , created : DateTime
    , modified : DateTime
    }


type SaveState
    = Unsaved
    | Saving
    | ErrorSaving Http.Error


type alias Editor =
    { lockMoments : AssocList.Dict Int Item
    , nextEditorId : EditorId
    , saved : SaveState
    }


ifDifferent : comparable -> comparable -> Maybe comparable
ifDifferent a b =
    if b /= a then
        Just b

    else
        Nothing


encodeItem : Id -> Maybe String -> Maybe Int -> Maybe Int -> JsonE.Value
encodeItem id name order version =
    JsonE.startObject
        |> JsonE.field "id" (id |> encodeId)
        |> JsonE.maybeField "name" JsonE.string name
        |> JsonE.maybeField "order" JsonE.int order
        |> JsonE.maybeField "version" JsonE.int version
        |> JsonE.finishObject


encodeLockMoments : LockMoments -> AssocList.Dict Int Item -> JsonE.Value
encodeLockMoments lockMoments items =
    let
        itemsById =
            items
                |> AssocList.values
                |> List.map (\item -> ( item.slug |> Slug.resolve idFromString item.name, item ))
                |> AssocList.fromList

        ids =
            [ lockMoments |> AssocList.keys, itemsById |> AssocList.keys ]
                |> List.concat
                |> EverySet.fromList
                |> EverySet.toList

        foldFunction id ( adds, edits, removes ) =
            let
                maybeItem =
                    AssocList.get id itemsById
            in
            case AssocList.get id lockMoments of
                Just lockMoment ->
                    case maybeItem of
                        Just item ->
                            let
                                editItem =
                                    encodeItem id
                                        (ifDifferent lockMoment.name item.name)
                                        (ifDifferent lockMoment.order (item.order |> String.toInt |> Maybe.withDefault lockMoment.order))
                                        (Just lockMoment.version)
                            in
                            ( adds, editItem :: edits, removes )

                        Nothing ->
                            let
                                removeItem =
                                    encodeItem id
                                        Nothing
                                        Nothing
                                        (Just lockMoment.version)
                            in
                            ( adds, edits, removeItem :: removes )

                Nothing ->
                    case maybeItem of
                        Just item ->
                            let
                                addItem =
                                    encodeItem id
                                        (Just item.name)
                                        (item.order |> String.toInt)
                                        Nothing
                            in
                            ( addItem :: adds, edits, removes )

                        Nothing ->
                            ( adds, edits, removes )

        ( add, edit, remove ) =
            ids |> List.foldl foldFunction ( [], [], [] )
    in
    JsonE.startObject
        |> JsonE.maybeField "add" (JsonE.list identity) (add |> Maybe.ifFalse List.isEmpty)
        |> JsonE.maybeField "edit" (JsonE.list identity) (edit |> Maybe.ifFalse List.isEmpty)
        |> JsonE.maybeField "remove" (JsonE.list identity) (remove |> Maybe.ifFalse List.isEmpty)
        |> JsonE.finishObject


itemFromLockMoment : Int -> ( Id, LockMoment ) -> ( EditorId, Item )
itemFromLockMoment index ( slug, { name, order, bets, version, created, modified } ) =
    ( index
    , { slug = Slug.Locked slug
      , name = name
      , order = order |> String.fromInt
      , bets = bets
      , version = version
      , created = created
      , modified = modified
      }
    )


newItem : Editor -> DateTime -> Item
newItem model created =
    { slug = Slug.Auto
    , name = ""
    , order =
        model.lockMoments
            |> AssocList.values
            |> List.filterMap (.order >> String.toInt)
            |> List.maximum
            |> Maybe.map ((+) 1)
            |> Maybe.withDefault 1
            |> String.fromInt
    , bets = 0
    , version = 0
    , created = created
    , modified = created
    }


init : LockMoments -> Editor
init lockMoments =
    let
        items =
            lockMoments
                |> AssocList.toList
                |> List.indexedMap itemFromLockMoment
                |> List.reverse
                |> AssocList.fromList
                |> Order.sortBy (.order >> String.toFloat)
    in
    { lockMoments = items
    , nextEditorId = items |> AssocList.size
    , saved = Unsaved
    }


getOrder : Item -> Maybe Float
getOrder =
    .order >> String.toFloat


setOrder : String -> Item -> Item
setOrder order item =
    { item | order = order }


updateLockMoments : (AssocList.Dict Int Item -> AssocList.Dict Int Item) -> Maybe Editor -> Maybe Editor
updateLockMoments editLockMoments =
    let
        editModel model =
            { model | lockMoments = model.lockMoments |> editLockMoments }
    in
    Maybe.map editModel


updateItem : EditorId -> (Item -> Item) -> Maybe Editor -> Maybe Editor
updateItem editorId editItem =
    updateLockMoments (AssocList.update editorId (Maybe.map editItem))


updateEditor : String -> (EditorMsg -> msg) -> (Game.Id -> LockMoments -> msg) -> Context -> EditorMsg -> Maybe Editor -> ( Maybe Editor, Cmd msg )
updateEditor origin wrap updateContext context msg maybeModel =
    case msg of
        Add created ->
            case created of
                Just now ->
                    let
                        editModel model =
                            { model
                                | lockMoments =
                                    model.lockMoments
                                        |> AssocList.insert model.nextEditorId (newItem model now)
                                        |> Order.sortBy getOrder
                                , nextEditorId = model.nextEditorId + 1
                            }
                    in
                    ( maybeModel |> Maybe.map editModel, Cmd.none )

                Nothing ->
                    ( maybeModel, DateTime.getNow |> Task.perform (Just >> Add >> wrap) )

        SetSlug editorId slug ->
            let
                updateSlug item =
                    { item | slug = Slug.set idFromString slug item.slug }
            in
            ( updateItem editorId updateSlug maybeModel, Cmd.none )

        SetName editorId name ->
            let
                updateName item =
                    { item | name = name }
            in
            ( updateItem editorId updateName maybeModel, Cmd.none )

        SetOrder resolve editorId order ->
            let
                change =
                    AssocList.update editorId (Maybe.map (setOrder order))

                reorder =
                    if resolve then
                        Order.simplifyAndSortBy getOrder (String.fromInt >> setOrder)

                    else
                        identity
            in
            ( updateLockMoments (change >> reorder) maybeModel, Cmd.none )

        Remove editorId ->
            ( updateLockMoments
                (AssocList.remove editorId >> Order.simplifyAndSortBy getOrder (String.fromInt >> setOrder))
                maybeModel
            , Cmd.none
            )

        ShowEditor ->
            ( context.lockMoments
                |> RemoteData.toMaybe
                |> Maybe.map (\r -> init r)
            , Cmd.none
            )

        CancelEdit ->
            ( Nothing, Cmd.none )

        SaveEdit ->
            case ( maybeModel, context.lockMoments |> RemoteData.toMaybe ) of
                ( Just model, Just previousLockMoments ) ->
                    let
                        handleResult result =
                            case result of
                                Ok lockMoments ->
                                    updateContext context.game lockMoments

                                Err error ->
                                    error |> SaveError |> wrap

                        cmd =
                            Api.post origin
                                { path = Api.Game context.game Api.LockMoments
                                , body = encodeLockMoments previousLockMoments model.lockMoments |> Http.jsonBody
                                , expect = Http.expectJson handleResult lockMomentsDecoder
                                }
                    in
                    ( Just { model | saved = Saving }, cmd )

                _ ->
                    ( maybeModel, Cmd.none )

        SaveError problem ->
            let
                editModel model =
                    { model | saved = ErrorSaving problem }
            in
            ( maybeModel |> Maybe.map editModel, Cmd.none )


itemNameValidator : Validator String
itemNameValidator =
    Validator.fromPredicate "Name must not be empty." String.isEmpty


itemOrderValidator : AssocList.Dict EditorId Item -> Validator Item
itemOrderValidator lockMoments =
    Order.validator getOrder lockMoments


itemSlugValidator : AssocList.Dict EditorId Item -> Validator Item
itemSlugValidator lockMoments =
    lockMoments
        |> AssocList.values
        |> Slug.validator idFromString (\{ slug, name } -> ( slug, name ))


itemValidator : AssocList.Dict EditorId Item -> Validator Item
itemValidator lockMoments =
    Validator.all
        [ itemNameValidator |> Validator.map .name
        , itemOrderValidator lockMoments
        , itemSlugValidator lockMoments
        ]


itemsValidator : Validator (AssocList.Dict EditorId Item)
itemsValidator lockMoments =
    (Validator.list (itemValidator lockMoments)
        |> Validator.map AssocList.values
    )
        lockMoments


viewItem : (EditorMsg -> msg) -> Editor -> EditorId -> Item -> Html msg
viewItem wrap editor editorId ({ slug, name, order, bets } as item) =
    let
        textField title type_ value action attrs =
            TextField.viewWithAttrs title type_ value action (Material.outlined :: attrs)

        orderNumber =
            order |> String.toFloat

        orderButtonAction modify =
            orderNumber |> Maybe.map (modify >> String.fromFloat >> SetOrder True editorId >> wrap)

        orderEditor =
            Html.div [ HtmlA.class "order" ]
                [ IconButton.view (Icon.arrowUp |> Icon.view)
                    "Move Up"
                    (orderButtonAction (\o -> o - 1.5))
                , textField "Order"
                    TextField.Number
                    order
                    (SetOrder False editorId >> wrap |> Just)
                    [ HtmlE.onBlur (SetOrder True editorId order |> wrap) ]
                , IconButton.view (Icon.arrowDown |> Icon.view)
                    "Move Down"
                    (orderButtonAction (\o -> o + 1.5))
                , Validator.view (itemOrderValidator editor.lockMoments) item
                ]

        slugEditor =
            Slug.view idFromString idToString (Just >> SetSlug editorId >> wrap) name slug
    in
    Html.li [ HtmlA.class "lock-moment-editor" ]
        [ orderEditor
        , Html.div [ HtmlA.class "details" ]
            [ Html.div [ HtmlA.class "inline" ]
                [ Html.span [ HtmlA.class "fullwidth" ]
                    [ slugEditor
                    , Validator.view (itemSlugValidator editor.lockMoments) item
                    ]
                , IconButton.view (Icon.trash |> Icon.view)
                    "Delete"
                    (Remove editorId |> wrap |> Maybe.whenNot (bets > 0))
                ]
            , textField "Name" TextField.Text name (SetName editorId >> wrap |> Just) [ HtmlA.required True ]
            , Validator.view itemNameValidator name
            ]
        ]


viewEditor : (EditorMsg -> msg) -> Context -> Maybe Editor -> List (Html msg)
viewEditor wrap context maybeModel =
    case maybeModel of
        Just model ->
            let
                savingState =
                    case model.saved of
                        ErrorSaving error ->
                            [ Html.p [ HtmlA.class "error" ]
                                [ error |> RemoteData.errorToString |> Html.text
                                ]
                            ]

                        Saving ->
                            [ Html.div [ HtmlA.class "loading" ]
                                [ Icon.spinner |> Icon.styled [ Icon.spinPulse ] |> Icon.view ]
                            ]

                        Unsaved ->
                            []

                editorContent _ =
                    [ Html.h3 [] [ Html.text "Lock Moments" ]
                    , Html.p []
                        [ Html.text "The moment at which the bet will be "
                        , Html.text "locked (users can no longer bet on them). "
                        , Html.text "Bets are displayed in order by this, so "
                        , Html.text "bets that lock first will be displayed "
                        , Html.text "first. You can't delete a lock moment with "
                        , Html.text "bets that have it, so change the bets to "
                        , Html.text "another lock moment or delete the bets "
                        , Html.text "first to delete the lock moment."
                        ]
                    , model.lockMoments
                        |> AssocList.toList
                        |> List.map (\( editorId, item ) -> ( String.fromInt editorId, viewItem wrap model editorId item ))
                        |> HtmlK.ol [ HtmlA.class "editors" ]
                    , Html.div [ HtmlA.class "moments-actions" ]
                        [ Button.view Button.Standard
                            Button.Padded
                            "Add New Lock Moment"
                            (Icon.add |> Icon.view |> Just)
                            (Add Nothing |> wrap |> Just)
                        ]
                    , Html.div [ HtmlA.class "save-state" ] savingState
                    ]

                canSave =
                    RemoteData.isLoaded context.lockMoments
                        && (model.saved /= Saving)
                        && Validator.valid itemsValidator model.lockMoments
            in
            [ Html.div [ HtmlA.class "overlay" ]
                [ Html.div [ HtmlA.class "background", CancelEdit |> wrap |> HtmlE.onClick ] []
                , [ [ context.lockMoments |> RemoteData.view editorContent
                    , [ Html.div [ HtmlA.class "controls" ]
                            [ Button.view Button.Standard
                                Button.Padded
                                "Cancel"
                                (Icon.times |> Icon.view |> Just)
                                (CancelEdit |> wrap |> Just)
                            , Button.view Button.Raised
                                Button.Padded
                                "Save"
                                (Icon.times |> Icon.view |> Just)
                                (SaveEdit |> wrap |> Maybe.when canSave)
                            ]
                      ]
                    ]
                        |> List.concat
                        |> Html.div [ HtmlA.id "lock-moments-editor" ]
                  ]
                    |> Html.div [ HtmlA.class "foreground" ]
                ]
            ]

        Nothing ->
            []
