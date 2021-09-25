module JoeBets.Bet.Editor.Model exposing
    ( ContextualOverlay(..)
    , Mode(..)
    , Model
    , Msg(..)
    , OptionChange(..)
    , OptionDiff
    , OptionEditor
    , Source
    , diff
    , encodeCancelAction
    , encodeCompleteAction
    , encodeDiff
    , encodeOptionDiff
    , initOption
    , initOptionFromEditable
    , resolveId
    , toBet
    )

import AssocList
import EverySet exposing (EverySet)
import Http
import JoeBets.Bet.Editor.EditableBet as EditableBet exposing (EditableBet, EditableOption)
import JoeBets.Bet.Model as Bet exposing (Bet)
import JoeBets.Bet.Option as Option
import JoeBets.Editing.Slug as Slug exposing (Slug)
import JoeBets.Editing.Uploader as Uploader exposing (Uploader)
import JoeBets.Game.Model as Game
import JoeBets.User.Model as User
import Json.Encode as JsonE
import Util.AssocList as AssocList
import Util.Json.Encode.Pipeline as JsonE
import Util.Maybe as Maybe
import Util.RemoteData as RemoteData exposing (RemoteData)


type Mode
    = EditBet
    | EditSuggestion


type alias Source =
    { id : Bet.Id
    , bet : RemoteData EditableBet
    }


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


type ContextualOverlay
    = CompleteOverlay { winners : EverySet Option.Id }
    | CancelOverlay { reason : String }


type alias Model =
    { gameId : Game.Id
    , mode : Mode
    , source : Maybe Source
    , id : Slug Bet.Id
    , name : String
    , description : String
    , spoiler : Bool
    , locksWhen : String
    , options : AssocList.Dict String OptionEditor
    , contextualOverlay : Maybe ContextualOverlay
    , internalIdCounter : Int
    }


resolveId : Model -> Bet.Id
resolveId { id, name } =
    id |> Slug.resolve Bet.idFromString name


toBet : User.Id -> Model -> Bet
toBet localUser { source, name, description, spoiler, locksWhen, options } =
    let
        maybeSourceBet =
            source |> Maybe.andThen (.bet >> RemoteData.toMaybe)

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

        author =
            maybeSourceBet |> Maybe.map (.author >> .id) |> Maybe.withDefault localUser

        fromEditableProgress editableProgress =
            case editableProgress of
                EditableBet.Voting ->
                    Bet.Voting { locksWhen = locksWhen }

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
                |> Maybe.map (.progress >> fromEditableProgress)
                |> Maybe.withDefault (Bet.Voting { locksWhen = locksWhen })
    in
    { name = name
    , author = author
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


type Msg
    = Load Game.Id Bet.Id (Result Http.Error EditableBet)
    | SetMode Mode
    | SetId String
    | SetName String
    | SetDescription String
    | SetSpoiler Bool
    | SetLocksWhen String
    | SetLocked Bool
    | Complete
    | Cancel
    | Reset
    | NewOption
    | ChangeOption String OptionChange
    | ChangeCancelReason String
    | SetWinner Option.Id Bool
    | ResolveOverlay Bool


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
        |> JsonE.field "id" (id |> Option.encodeId)
        |> JsonE.maybeField "name" JsonE.string name
        |> JsonE.maybeField "image" (Maybe.map JsonE.string >> Maybe.withDefault JsonE.null) image
        |> JsonE.maybeField "order" JsonE.int order
        |> JsonE.finishObject


type alias Diff =
    { version : Maybe Int
    , name : Maybe String
    , description : Maybe String
    , spoiler : Maybe Bool
    , locksWhen : Maybe String
    , removeOptions : Maybe (List Option.Id)
    , editOptions : Maybe (List OptionDiff)
    , addOptions : Maybe (List OptionDiff)
    }


encodeDiff : Diff -> JsonE.Value
encodeDiff { version, name, description, spoiler, locksWhen, removeOptions, editOptions, addOptions } =
    JsonE.startObject
        |> JsonE.maybeField "version" JsonE.int version
        |> JsonE.maybeField "name" JsonE.string name
        |> JsonE.maybeField "description" JsonE.string description
        |> JsonE.maybeField "spoiler" JsonE.bool spoiler
        |> JsonE.maybeField "locksWhen" JsonE.string locksWhen
        |> JsonE.maybeField "removeOptions" (JsonE.list Option.encodeId) removeOptions
        |> JsonE.maybeField "editOptions" (JsonE.list encodeOptionDiff) editOptions
        |> JsonE.maybeField "addOptions" (JsonE.list encodeOptionDiff) addOptions
        |> JsonE.finishObject


diff : Model -> Result String Diff
diff { source, name, description, spoiler, locksWhen, options } =
    case source of
        Just existing ->
            case existing.bet |> RemoteData.toMaybe of
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

                                ( Just _, Nothing ) ->
                                    { diffs | remove = optionId :: remove }

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
                        (Maybe.ifDifferent bet.locksWhen locksWhen)
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
            Diff
                Nothing
                (Just name)
                (Just description)
                (Just spoiler)
                (Just locksWhen)
                Nothing
                Nothing
                (options |> AssocList.values |> List.sortBy .order |> List.map optionDiff |> Just)
                |> Ok


type alias CompleteAction =
    { version : Int
    , winners : EverySet Option.Id
    }


encodeCompleteAction : CompleteAction -> JsonE.Value
encodeCompleteAction { version, winners } =
    JsonE.startObject
        |> JsonE.field "version" (version |> JsonE.int)
        |> JsonE.field "winners" (winners |> EverySet.toList |> JsonE.list Option.encodeId)
        |> JsonE.finishObject


type alias CancelAction =
    { version : Int
    , reason : String
    }


encodeCancelAction : CancelAction -> JsonE.Value
encodeCancelAction { version, reason } =
    JsonE.startObject
        |> JsonE.field "version" (version |> JsonE.int)
        |> JsonE.field "reason" (reason |> JsonE.string)
        |> JsonE.finishObject
