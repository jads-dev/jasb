module Jasb.Bet.Editor.Model exposing
    ( ContextualDialog
    , DialogContext(..)
    , LoadReason(..)
    , Mode(..)
    , Model
    , Msg(..)
    , OptionChange(..)
    , OptionDiff
    , OptionEditor
    , closeDialog
    , diff
    , encodeCancelAction
    , encodeCompleteAction
    , encodeDiff
    , encodeOptionDiff
    , initDialog
    , initOption
    , initOptionFromEditable
    , lockMomentContext
    , resolveId
    , showDialog
    , toBet
    )

import AssocList
import EverySet exposing (EverySet)
import Jasb.Api.Data as Api
import Jasb.Api.IdData as Api
import Jasb.Api.Model as Api
import Jasb.Bet.Editor.EditableBet as EditableBet exposing (EditableBet, EditableOption)
import Jasb.Bet.Editor.LockMoment as LockMoment
import Jasb.Bet.Editor.LockMoment.Editor as LockMoment
import Jasb.Bet.Editor.QuickAdd as QuickAdd
import Jasb.Bet.Editor.RangeAdd as RangeAdd
import Jasb.Bet.Model as Bet exposing (Bet)
import Jasb.Bet.Option as Option
import Jasb.Editing.Slug as Slug exposing (Slug)
import Jasb.Editing.Uploader as Uploader exposing (Uploader)
import Jasb.Game.Id as Game
import Jasb.User.Model as User
import Json.Encode as JsonE
import Util.AssocList as AssocList
import Util.Json.Encode.Pipeline as JsonE
import Util.Maybe as Maybe


type Mode
    = EditBet
    | EditSuggestion


type alias OptionEditor =
    { id : Slug Option.Id
    , name : String
    , image : Uploader
    , order : Int
    }


initOption : Int -> Int -> ( String, OptionEditor )
initOption internalIdCounter order =
    ( "NEW!" ++ (internalIdCounter |> String.fromInt)
    , { id = Slug.Auto
      , name = ""
      , image = Uploader.init
      , order = order
      }
    )


initOptionFromEditable : ( Option.Id, EditableOption ) -> ( String, OptionEditor )
initOptionFromEditable ( id, { name, image, order } ) =
    ( id |> Option.idToString
    , { id = Slug.Locked id
      , name = name
      , image = image |> Maybe.withDefault "" |> Uploader.fromUrl
      , order = order
      }
    )


type DialogContext
    = CompleteDialog { winners : EverySet Option.Id }
    | CancelDialog { reason : String }
    | NoDialog


type alias ContextualDialog =
    { open : Bool, context : DialogContext }


initDialog : ContextualDialog
initDialog =
    { open = False, context = NoDialog }


showDialog : DialogContext -> ContextualDialog -> ContextualDialog
showDialog context dialog =
    { dialog | open = True, context = context }


closeDialog : ContextualDialog -> ContextualDialog
closeDialog dialog =
    { dialog | open = False }


type alias Model =
    { gameId : Game.Id
    , mode : Mode
    , source : Api.IdData Bet.Id EditableBet
    , id : Slug Bet.Id
    , name : String
    , description : String
    , spoiler : Bool
    , lockMoments : Api.Data LockMoment.LockMoments
    , lockMomentEditor : Maybe LockMoment.Editor
    , lockMoment : Maybe LockMoment.Id
    , options : AssocList.Dict String OptionEditor
    , contextualDialog : ContextualDialog
    , internalIdCounter : Int
    , quickAdd : QuickAdd.Model
    , rangeAdd : RangeAdd.Model
    }


lockMomentContext : Model -> LockMoment.Context
lockMomentContext { gameId, lockMoments } =
    { game = gameId, lockMoments = lockMoments }


resolveId : Model -> Bet.Id
resolveId { id, name } =
    id |> Slug.resolve Bet.idFromString name


toBet : User.Id -> Model -> Bet
toBet _ { source, name, description, spoiler, lockMoments, lockMoment, options } =
    let
        maybeSourceBet =
            source |> Api.idDataToMaybe |> Maybe.map Tuple.second

        toOption option =
            let
                optionId =
                    option.id |> Slug.resolve Option.idFromString option.name
            in
            ( optionId
            , { name = option.name
              , image = option.image |> Uploader.toUrl |> Maybe.ifFalse String.isEmpty
              , stakes =
                    maybeSourceBet
                        |> Maybe.andThen (.options >> AssocList.get optionId)
                        |> Maybe.map .stakes
                        |> Maybe.withDefault AssocList.empty
              }
            )

        fromEditableProgress editableProgress =
            case editableProgress of
                EditableBet.Voting ->
                    Bet.Voting { lockMoment = Maybe.map2 LockMoment.name (lockMoments |> Api.dataToMaybe) lockMoment |> Maybe.withDefault "" }

                EditableBet.Locked ->
                    Bet.Locked {}

                EditableBet.Complete _ ->
                    Bet.Complete
                        { winners =
                            maybeSourceBet
                                |> Maybe.map (.options >> AssocList.filter (\_ v -> v.won) >> AssocList.keySet)
                                |> Maybe.withDefault EverySet.empty
                        }

                EditableBet.Cancelled { reason } ->
                    Bet.Cancelled { reason = reason }

        progress =
            maybeSourceBet
                |> Maybe.map .progress
                |> Maybe.withDefault EditableBet.Voting
                |> fromEditableProgress
    in
    { name = name
    , description = description
    , spoiler = spoiler
    , progress = progress
    , options =
        options
            |> AssocList.values
            |> List.sortBy .order
            |> List.map toOption
            |> List.reverse
            |> AssocList.fromList
    }


type LoadReason
    = Initial
    | Change


type Msg
    = Load Game.Id Bet.Id LoadReason (Api.Response EditableBet)
    | LoadLockMoments Game.Id (Api.Response LockMoment.LockMoments)
    | EditLockMoments LockMoment.EditorMsg
    | SetMode Mode
    | SetId String
    | SetName String
    | SetDescription String
    | SetSpoiler Bool
    | SetLockMoment (Maybe LockMoment.Id)
    | SetLocked Bool
    | Complete
    | RevertComplete
    | Cancel
    | RevertCancel
    | Reset
    | NewOption
    | ChangeOption String OptionChange
    | ChangeCancelReason String
    | SetWinner Option.Id Bool
    | ResolveDialog Bool
    | QuickAdd QuickAdd.Msg
    | RangeAdd RangeAdd.Msg
    | Save
    | Saved Bet.Id (Api.Response EditableBet)


type OptionChange
    = SetOptionId String
    | SetOptionName String
    | OptionImageUploaderMsg Uploader.Msg
    | SetOptionOrder String
    | DeleteOption


type alias OptionDiff =
    { version : Maybe Int
    , id : Option.Id
    , name : Maybe String
    , image : Maybe (Maybe String)
    , order : Maybe Int
    }


encodeOptionDiff : OptionDiff -> JsonE.Value
encodeOptionDiff { version, id, name, image, order } =
    JsonE.startObject
        |> JsonE.maybeField "version" JsonE.int version
        |> JsonE.field "id" Option.encodeId id
        |> JsonE.maybeField "name" JsonE.string name
        |> JsonE.maybeField "image" (Maybe.map JsonE.string >> Maybe.withDefault JsonE.null) image
        |> JsonE.maybeField "order" JsonE.int order
        |> JsonE.finishObject


type alias Diff =
    { version : Maybe Int
    , name : Maybe String
    , description : Maybe String
    , spoiler : Maybe Bool
    , lockMoment : Maybe LockMoment.Id
    , removeOptions : Maybe (List OptionDiff)
    , editOptions : Maybe (List OptionDiff)
    , addOptions : Maybe (List OptionDiff)
    }


encodeDiff : Diff -> JsonE.Value
encodeDiff { version, name, description, spoiler, lockMoment, removeOptions, editOptions, addOptions } =
    JsonE.startObject
        |> JsonE.maybeField "version" JsonE.int version
        |> JsonE.maybeField "name" JsonE.string name
        |> JsonE.maybeField "description" JsonE.string description
        |> JsonE.maybeField "spoiler" JsonE.bool spoiler
        |> JsonE.maybeField "lockMoment" LockMoment.encodeId lockMoment
        |> JsonE.maybeField "removeOptions" (JsonE.list encodeOptionDiff) removeOptions
        |> JsonE.maybeField "editOptions" (JsonE.list encodeOptionDiff) editOptions
        |> JsonE.maybeField "addOptions" (JsonE.list encodeOptionDiff) addOptions
        |> JsonE.finishObject


diff : Model -> Result String Diff
diff { source, name, description, spoiler, lockMoment, options } =
    case source |> Api.idDataToData of
        Just ( _, existingBet ) ->
            case existingBet |> Api.dataToMaybe of
                Just bet ->
                    let
                        withId newOption =
                            ( newOption.id |> Slug.resolve Option.idFromString newOption.name
                            , newOption
                            )

                        newOptions =
                            options |> AssocList.values |> List.map withId |> AssocList.fromList

                        diffOf optionId ({ remove, edit, add } as diffs) =
                            case ( AssocList.get optionId bet.options, AssocList.get optionId newOptions ) of
                                ( Nothing, Nothing ) ->
                                    diffs

                                ( Just old, Nothing ) ->
                                    let
                                        optionDiff =
                                            OptionDiff
                                                (Just old.version)
                                                optionId
                                                Nothing
                                                Nothing
                                                Nothing
                                    in
                                    { diffs | remove = optionDiff :: remove }

                                ( Just old, Just new ) ->
                                    let
                                        optionDiff =
                                            OptionDiff
                                                (Just old.version)
                                                optionId
                                                (Maybe.ifDifferent old.name new.name)
                                                (Maybe.ifDifferent old.image (new.image |> Uploader.toUrl |> Maybe.ifFalse String.isEmpty))
                                                (Maybe.ifDifferent old.order new.order)
                                    in
                                    if optionDiff.name == Nothing && optionDiff.image == Nothing && optionDiff.order == Nothing then
                                        diffs

                                    else
                                        { diffs | edit = optionDiff :: edit }

                                ( Nothing, Just new ) ->
                                    let
                                        optionDiff =
                                            OptionDiff
                                                Nothing
                                                optionId
                                                (Just new.name)
                                                (Just (new.image |> Uploader.toUrl |> Maybe.ifFalse String.isEmpty))
                                                (Just new.order)
                                    in
                                    { diffs | add = optionDiff :: add }

                        resolvedOptions =
                            [ bet.options |> AssocList.keys, newOptions |> AssocList.keys ]
                                |> List.concat
                                |> EverySet.fromList
                                |> EverySet.foldl diffOf { remove = [], edit = [], add = [] }
                    in
                    Diff
                        (Just bet.version)
                        (Maybe.ifDifferent bet.name name)
                        (Maybe.ifDifferent bet.description description)
                        (Maybe.ifDifferent bet.spoiler spoiler)
                        (Maybe.ifDifferent bet.lockMoment (lockMoment |> Maybe.withDefault bet.lockMoment))
                        (resolvedOptions.remove |> Maybe.ifFalse List.isEmpty)
                        (resolvedOptions.edit |> Maybe.ifFalse List.isEmpty)
                        (resolvedOptions.add |> Maybe.ifFalse List.isEmpty)
                        |> Ok

                Nothing ->
                    Err "Can't edit before the data is loaded."

        Nothing ->
            let
                optionDiff option =
                    OptionDiff
                        Nothing
                        (option.id |> Slug.resolve Option.idFromString option.name)
                        (Just option.name)
                        (Just (option.image |> Uploader.toUrl |> Maybe.ifTrue (String.isEmpty >> not)))
                        Nothing
            in
            case lockMoment of
                Just id ->
                    Diff
                        Nothing
                        (Just name)
                        (Just description)
                        (Just spoiler)
                        (Just id)
                        Nothing
                        Nothing
                        (options |> AssocList.values |> List.sortBy .order |> List.map optionDiff |> Just)
                        |> Ok

                Nothing ->
                    Err "Must give a lock moment."


type alias CompleteAction =
    { version : Int
    , winners : EverySet Option.Id
    }


encodeCompleteAction : CompleteAction -> JsonE.Value
encodeCompleteAction { version, winners } =
    JsonE.startObject
        |> JsonE.field "version" JsonE.int version
        |> JsonE.field "winners" (JsonE.list Option.encodeId) (winners |> EverySet.toList)
        |> JsonE.finishObject


type alias CancelAction =
    { version : Int
    , reason : String
    }


encodeCancelAction : CancelAction -> JsonE.Value
encodeCancelAction { version, reason } =
    JsonE.startObject
        |> JsonE.field "version" JsonE.int version
        |> JsonE.field "reason" JsonE.string reason
        |> JsonE.finishObject
