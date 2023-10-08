module JoeBets.Bet.Editor.LockMoment.Editor exposing
    ( Editor
    , EditorMsg(..)
    , Item
    , close
    , itemFromLockMoment
    , updateEditor
    , viewEditor
    )

import AssocList
import EverySet
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Events as HtmlE
import Html.Keyed as HtmlK
import JoeBets.Api as Api
import JoeBets.Api.Action as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.Error as Api
import JoeBets.Api.Path as Api
import JoeBets.Bet.Editor.LockMoment exposing (..)
import JoeBets.Editing.Order as Order
import JoeBets.Editing.Slug as Slug exposing (Slug)
import JoeBets.Editing.Validator as Validator exposing (Validator)
import JoeBets.Game.Id as Game
import Json.Encode as JsonE
import Material.Button as Button
import Material.Dialog as Dialog
import Material.IconButton as IconButton
import Material.TextField as TextField
import Task
import Time.DateTime as DateTime exposing (DateTime)
import Util.Json.Encode.Pipeline as JsonE
import Util.Maybe as Maybe


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
    | SaveError Api.Error


type alias Item =
    { slug : Slug Id
    , name : String
    , order : String
    , bets : Int
    , version : Int
    , created : DateTime
    , modified : DateTime
    }


type alias Editor =
    { open : Bool
    , lockMoments : AssocList.Dict Int Item
    , nextEditorId : EditorId
    , save : Api.ActionState
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
        |> JsonE.field "id" encodeId id
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
    { open = True
    , lockMoments = items
    , nextEditorId = items |> AssocList.size
    , save = Api.initAction
    }


close : Maybe Editor -> Maybe Editor
close =
    let
        internal model =
            { model | open = False }
    in
    Maybe.map internal


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
                |> Api.dataToMaybe
                |> Maybe.map (\r -> init r)
            , Cmd.none
            )

        CancelEdit ->
            ( maybeModel |> close, Cmd.none )

        SaveEdit ->
            case ( maybeModel, context.lockMoments |> Api.dataToMaybe ) of
                ( Just model, Just previousLockMoments ) ->
                    let
                        handleResult result =
                            case result of
                                Ok lockMoments ->
                                    updateContext context.game lockMoments

                                Err error ->
                                    error |> SaveError |> wrap

                        ( save, cmd ) =
                            Api.post origin
                                { path = Api.Game context.game Api.LockMoments
                                , body = encodeLockMoments previousLockMoments model.lockMoments
                                , wrap = handleResult
                                , decoder = lockMomentsDecoder
                                }
                                |> Api.doAction model.save
                    in
                    ( Just { model | save = save }, cmd )

                _ ->
                    ( maybeModel, Cmd.none )

        SaveError problem ->
            let
                editModel model =
                    { model | save = Api.failAction problem }
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
        orderNumber =
            order |> String.toFloat

        whenNotSaving =
            Api.ifNotWorking editor.save

        orderButtonAction modify =
            orderNumber
                |> Maybe.map (modify >> String.fromFloat >> SetOrder True editorId >> wrap)
                |> whenNotSaving

        orderEditor =
            Html.div [ HtmlA.class "order" ]
                [ IconButton.icon (Icon.arrowUp |> Icon.view)
                    "Move Up"
                    |> IconButton.button (orderButtonAction (\o -> o - 1.5))
                    |> IconButton.view
                , TextField.outlined "Order" (SetOrder False editorId >> wrap |> Just) order
                    |> TextField.attrs [ HtmlE.onBlur (SetOrder True editorId order |> wrap) ]
                    |> TextField.view
                , IconButton.icon (Icon.arrowDown |> Icon.view)
                    "Move Down"
                    |> IconButton.button (orderButtonAction (\o -> o + 1.5))
                    |> IconButton.view
                , Validator.view (itemOrderValidator editor.lockMoments) item
                ]

        slugEditor =
            Slug.view
                idFromString
                idToString
                (Just >> SetSlug editorId >> wrap |> Just |> whenNotSaving)
                name
                slug
    in
    Html.li [ HtmlA.class "lock-moment-editor" ]
        [ orderEditor
        , Html.div [ HtmlA.class "details" ]
            [ Html.div [ HtmlA.class "inline" ]
                [ Html.span [ HtmlA.class "fullwidth" ]
                    [ slugEditor
                    , Validator.view (itemSlugValidator editor.lockMoments) item
                    ]
                , IconButton.icon (Icon.trash |> Icon.view)
                    "Delete"
                    |> IconButton.button (Remove editorId |> wrap |> Maybe.whenNot (bets > 0) |> whenNotSaving)
                    |> IconButton.view
                ]
            , TextField.outlined "Name" (SetName editorId >> wrap |> Just |> whenNotSaving) name
                |> TextField.required True
                |> TextField.view
            , Validator.view itemNameValidator name
            ]
        ]


viewEditor : (EditorMsg -> msg) -> Context -> Maybe Editor -> List (Html msg)
viewEditor wrap context maybeModel =
    let
        alwaysContent =
            [ Html.p []
                [ Html.text "The moment at which the bet will be "
                , Html.text "locked (users can no longer bet on them). "
                , Html.text "Bets are displayed in order by this, so "
                , Html.text "bets that lock first will be displayed "
                , Html.text "first. You can't delete a lock moment with "
                , Html.text "bets that have it, so change the bets to "
                , Html.text "another lock moment or delete the bets "
                , Html.text "first to delete the lock moment."
                ]
            ]

        ( open, content, canSave ) =
            case maybeModel of
                Just model ->
                    let
                        editorContent _ =
                            [ model.lockMoments
                                |> AssocList.toList
                                |> List.map (\( editorId, item ) -> ( String.fromInt editorId, viewItem wrap model editorId item ))
                                |> HtmlK.ol [ HtmlA.class "editors" ]
                            , Html.div [ HtmlA.class "moments-actions" ]
                                [ Button.text "Add New Lock Moment"
                                    |> Button.button (Add Nothing |> wrap |> Just)
                                    |> Button.icon [ Icon.add |> Icon.view ]
                                    |> Button.view
                                ]
                            , Api.viewAction [] model.save |> Html.div [ HtmlA.class "save-state" ]
                            ]

                        canSaveReal =
                            Api.isLoaded context.lockMoments
                                && (model.save |> Api.isWorking |> not)
                                && Validator.valid itemsValidator model.lockMoments
                    in
                    ( model.open
                    , context.lockMoments |> Api.viewData Api.viewOrError editorContent
                    , canSaveReal
                    )

                Nothing ->
                    ( False, [], False )
    in
    [ Dialog.dialog (CancelEdit |> wrap)
        (List.append alwaysContent content)
        [ Button.text "Cancel"
            |> Button.button (CancelEdit |> wrap |> Just)
            |> Button.icon [ Icon.times |> Icon.view ]
            |> Button.view
        , Button.filled "Save"
            |> Button.button (SaveEdit |> wrap |> Maybe.when canSave)
            |> Button.icon [ Icon.save |> Icon.view ]
            |> Button.view
        ]
        open
        |> Dialog.headline [ Html.text "Lock Moments" ]
        |> Dialog.attrs [ HtmlA.id "lock-moments-editor" ]
        |> Dialog.view
    ]
