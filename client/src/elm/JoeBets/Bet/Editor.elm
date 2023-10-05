module JoeBets.Bet.Editor exposing
    ( empty
    , isNew
    , load
    , update
    , view
    )

import AssocList
import Browser.Navigation as Browser
import EverySet
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Keyed as HtmlK
import JoeBets.Api as Api
import JoeBets.Api.Action as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.IdData as Api
import JoeBets.Api.Path as Api
import JoeBets.Bet as Bet
import JoeBets.Bet.Editor.EditableBet as EditableBet exposing (EditableBet)
import JoeBets.Bet.Editor.LockMoment as LockMoment
import JoeBets.Bet.Editor.LockMoment.Editor as LockMoment
import JoeBets.Bet.Editor.LockMoment.Selector as LockMoment
import JoeBets.Bet.Editor.Model exposing (..)
import JoeBets.Bet.Model as Bet
import JoeBets.Bet.Option as Option
import JoeBets.Editing.Slug as Slug
import JoeBets.Editing.Uploader as Uploader
import JoeBets.Editing.Validator as Validator exposing (Validator)
import JoeBets.Game.Id as Game
import JoeBets.Overlay as Overlay
import JoeBets.Page.Edit.Model as Edit
import JoeBets.Route as Route exposing (Route)
import JoeBets.User as User
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Model as User
import Json.Encode as JsonE
import List.Extra as List
import Material.Button as Button
import Material.IconButton as IconButton
import Material.Switch as Switch
import Material.TextField as TextField
import Time.DateTime as DateTime
import Time.Model as Time
import Util.AssocList as AssocList
import Util.EverySet as EverySet
import Util.Maybe as Maybe


type alias Parent a =
    { a
        | origin : String
        , navigationKey : Browser.Key
    }


empty : String -> (Msg -> msg) -> Bool -> Game.Id -> Edit.EditMode -> ( Model, Cmd msg )
empty origin wrap canManageBets gameId editMode =
    let
        ( source, id, loadBetCmd ) =
            case editMode of
                Edit.Edit toEditId ->
                    let
                        ( state, requestCmd ) =
                            { path = Api.Game gameId (Api.Bet toEditId Api.Edit)
                            , wrap = Load gameId toEditId Initial >> wrap
                            , decoder = EditableBet.decoder
                            }
                                |> Api.get origin
                                |> Api.initGetIdData toEditId
                    in
                    ( state, Slug.Locked toEditId, requestCmd )

                _ ->
                    ( Api.initIdData, Slug.Auto, Cmd.none )

        ( lockMoments, lockMomentsCmd ) =
            { path = Api.Game gameId Api.LockMoments
            , wrap = LoadLockMoments gameId >> wrap
            , decoder = LockMoment.lockMomentsDecoder
            }
                |> Api.get origin
                |> Api.initGetData

        mode =
            if not canManageBets || editMode == Edit.Suggest then
                EditSuggestion

            else
                EditBet
    in
    ( { mode = mode
      , source = source
      , gameId = gameId
      , id = id
      , name = ""
      , description = ""
      , spoiler = True
      , lockMoments = lockMoments
      , lockMomentEditor = Nothing
      , lockMoment = Nothing
      , options = AssocList.empty
      , contextualOverlay = Nothing
      , internalIdCounter = 0
      }
    , Cmd.batch [ loadBetCmd, lockMomentsCmd ]
    )


isNew : Model -> Bool
isNew { source } =
    Api.isIdDataUnstarted source


load : String -> User.WithId -> (Msg -> msg) -> Game.Id -> Edit.EditMode -> ( Model, Cmd msg )
load origin localUser wrap gameId editMode =
    let
        canManageBets =
            Auth.canManageBets gameId (Just localUser)
    in
    empty origin wrap canManageBets gameId editMode


fromSource : Bet.Id -> EditableBet -> Model -> Model
fromSource bet editableBet model =
    { model
        | id = bet |> Slug.Locked
        , name = editableBet.name
        , description = editableBet.description
        , spoiler = editableBet.spoiler
        , lockMoment = Just editableBet.lockMoment
        , options =
            editableBet.options
                |> AssocList.toList
                |> List.map initOptionFromEditable
                |> AssocList.fromList
                |> AssocList.sortBy (\_ v -> v.order)
        , source = model.source |> Api.updateIdDataValue bet (\_ -> editableBet)
    }


update : (Msg -> msg) -> Msg -> Parent a -> Model -> ( Model, Cmd msg )
update wrap msg ({ origin, navigationKey } as parent) model =
    case msg of
        Load game bet loadReason result ->
            if model.gameId == game then
                let
                    source =
                        model.source |> Api.updateIdData bet result

                    withSource =
                        { model | source = source }
                in
                case loadReason of
                    Initial ->
                        let
                            updateEditorFields =
                                case result of
                                    Ok editableBet ->
                                        fromSource bet editableBet

                                    Err _ ->
                                        identity
                        in
                        ( withSource |> updateEditorFields, Cmd.none )

                    Change ->
                        ( withSource, Cmd.none )

            else
                ( model, Cmd.none )

        LoadLockMoments game result ->
            let
                isSaving =
                    Maybe.map .save
                        >> Maybe.map Api.isWorking
                        >> Maybe.withDefault False

                closeIfSaving editor =
                    if isSaving editor then
                        Nothing

                    else
                        editor

                setIf m =
                    if model.gameId == game then
                        { m
                            | lockMoments = m.lockMoments |> Api.updateData result
                            , lockMomentEditor = m.lockMomentEditor |> closeIfSaving
                        }

                    else
                        m
            in
            ( model |> setIf, Cmd.none )

        EditLockMoments editLockMomentsMsg ->
            let
                ( editor, cmd ) =
                    LockMoment.updateEditor
                        origin
                        (EditLockMoments >> wrap)
                        (\game lockMoments -> LoadLockMoments game (Ok lockMoments) |> wrap)
                        (model |> lockMomentContext)
                        editLockMomentsMsg
                        model.lockMomentEditor
            in
            ( { model | lockMomentEditor = editor }, cmd )

        Reset ->
            case model.source |> Api.idDataToData of
                Just ( id, bet ) ->
                    case bet |> Api.dataToMaybe of
                        Just editableBet ->
                            ( model |> fromSource id editableBet, Cmd.none )

                        Nothing ->
                            ( model, Cmd.none )

                Nothing ->
                    let
                        editMode =
                            case model.mode of
                                EditBet ->
                                    Edit.New

                                EditSuggestion ->
                                    Edit.Suggest
                    in
                    empty origin wrap False model.gameId editMode

        SetMode mode ->
            ( { model | mode = mode }, Cmd.none )

        SetId id ->
            ( { model | id = Slug.set Bet.idFromString (id |> Maybe.ifFalse String.isEmpty) model.id }, Cmd.none )

        SetName name ->
            ( { model | name = name }, Cmd.none )

        SetDescription description ->
            ( { model | description = description }, Cmd.none )

        SetSpoiler isSpoiler ->
            ( { model | spoiler = isSpoiler }, Cmd.none )

        SetLockMoment lockMoment ->
            ( { model | lockMoment = lockMoment }, Cmd.none )

        SetLocked locked ->
            case model.source |> Api.idDataToMaybe of
                Just ( betId, bet ) ->
                    let
                        action =
                            if locked then
                                Api.Lock

                            else
                                Api.Unlock

                        ( source, request ) =
                            { path = action |> Api.Bet betId |> Api.Game model.gameId
                            , body = [ ( "version", JsonE.int bet.version ) ] |> JsonE.object
                            , wrap = Load model.gameId betId Change >> wrap
                            , decoder = EditableBet.decoder
                            }
                                |> Api.post origin
                                |> Api.getIdData betId model.source
                    in
                    ( { model | source = source }, request )

                Nothing ->
                    ( model, Cmd.none )

        Complete ->
            ( { model | contextualOverlay = { winners = EverySet.empty } |> CompleteOverlay |> Just }, Cmd.none )

        RevertComplete ->
            case model.source |> Api.idDataToMaybe of
                Just ( betId, bet ) ->
                    let
                        ( source, request ) =
                            { path = Api.RevertComplete |> Api.Bet betId |> Api.Game model.gameId
                            , body = [ ( "version", JsonE.int bet.version ) ] |> JsonE.object
                            , wrap = Load model.gameId betId Change >> wrap
                            , decoder = EditableBet.decoder
                            }
                                |> Api.post origin
                                |> Api.getIdData betId model.source
                    in
                    ( { model | source = source }, request )

                Nothing ->
                    ( model, Cmd.none )

        Cancel ->
            ( { model | contextualOverlay = { reason = "" } |> CancelOverlay |> Just }, Cmd.none )

        RevertCancel ->
            case model.source |> Api.idDataToMaybe of
                Just ( betId, bet ) ->
                    let
                        ( source, request ) =
                            { path = Api.RevertCancel |> Api.Bet betId |> Api.Game model.gameId
                            , body = [ ( "version", JsonE.int bet.version ) ] |> JsonE.object
                            , wrap = Load model.gameId betId Change >> wrap
                            , decoder = EditableBet.decoder
                            }
                                |> Api.post origin
                                |> Api.getIdData betId model.source
                    in
                    ( { model | source = source }, request )

                Nothing ->
                    ( model, Cmd.none )

        NewOption ->
            let
                maxOrder _ option max =
                    if option.order > max then
                        option.order

                    else
                        max

                newOrder =
                    model.options |> AssocList.foldr maxOrder 0 |> (+) 1

                ( id, value ) =
                    initOption model.internalIdCounter newOrder
            in
            ( { model
                | options = model.options |> AssocList.insert id value |> AssocList.sortBy (\_ v -> v.order)
                , internalIdCounter = model.internalIdCounter + 1
              }
            , Cmd.none
            )

        ChangeOption internalId optionChange ->
            let
                replaceOption replacement =
                    { model | options = model.options |> AssocList.update internalId (Maybe.map replacement) }
            in
            case optionChange of
                SetOptionId id ->
                    let
                        setIdInOption option =
                            { option | id = Slug.set Option.idFromString (id |> Maybe.ifFalse String.isEmpty) option.id }
                    in
                    ( replaceOption setIdInOption, Cmd.none )

                SetOptionName name ->
                    ( replaceOption (\option -> { option | name = name }), Cmd.none )

                OptionImageUploaderMsg uploaderMsg ->
                    case model.options |> AssocList.get internalId of
                        Just option ->
                            let
                                ( image, cmd ) =
                                    Uploader.update
                                        (OptionImageUploaderMsg >> ChangeOption internalId >> wrap)
                                        uploaderMsg
                                        parent
                                        imageUploaderModel
                                        option.image

                                replaceImageInOption _ =
                                    { option | image = image } |> Just

                                newOptions =
                                    model.options |> AssocList.update internalId replaceImageInOption
                            in
                            ( { model | options = newOptions }, cmd )

                        Nothing ->
                            ( model, Cmd.none )

                SetOptionOrder order ->
                    case order |> String.toInt of
                        Just newOrder ->
                            let
                                newIndex id option =
                                    if id == internalId then
                                        if option.order > newOrder then
                                            toFloat newOrder - 0.5

                                        else
                                            toFloat newOrder + 0.5

                                    else
                                        toFloat option.order

                                newOrders =
                                    model.options
                                        |> AssocList.map newIndex
                                        |> AssocList.toList
                                        |> List.sortBy Tuple.second
                                        |> List.indexedMap (\o ( id, _ ) -> ( id, o + 1 ))
                                        |> AssocList.fromList

                                replaceOrder id option =
                                    { option | order = newOrders |> AssocList.get id |> Maybe.withDefault option.order }
                            in
                            ( { model | options = model.options |> AssocList.map replaceOrder |> AssocList.sortBy (\_ v -> v.order) }, Cmd.none )

                        Nothing ->
                            ( model, Cmd.none )

                DeleteOption ->
                    let
                        newOptions =
                            model.options
                                |> AssocList.remove internalId
                                |> AssocList.sortBy (\_ o -> o.order)
                                |> AssocList.indexedMap (\i _ o -> { o | order = i + 1 })
                    in
                    ( { model | options = newOptions }, Cmd.none )

        ResolveOverlay commit ->
            let
                changeRequestFromBet path body m ( betId, bet ) =
                    { path = path |> Api.Bet betId |> Api.Game m.gameId
                    , body = body bet
                    , wrap = Load m.gameId betId Change >> wrap
                    , decoder = EditableBet.decoder
                    }
                        |> Api.post origin
                        |> Api.getIdData betId m.source

                makeChangeRequest path body m =
                    m.source
                        |> Api.idDataToMaybe
                        |> Maybe.map (changeRequestFromBet path body m)

                fromOverlay overlay =
                    if commit then
                        case overlay of
                            CancelOverlay { reason } ->
                                if String.isEmpty reason then
                                    Nothing

                                else
                                    let
                                        body bet =
                                            { version = bet.version, reason = reason }
                                                |> encodeCancelAction
                                    in
                                    makeChangeRequest
                                        Api.Cancel
                                        body
                                        model

                            CompleteOverlay { winners } ->
                                if EverySet.isEmpty winners then
                                    Nothing

                                else
                                    let
                                        body bet =
                                            { version = bet.version, winners = winners }
                                                |> encodeCompleteAction
                                    in
                                    makeChangeRequest
                                        Api.Complete
                                        body
                                        model

                    else
                        Nothing

                ( source, cmd ) =
                    model.contextualOverlay
                        |> Maybe.andThen fromOverlay
                        |> Maybe.withDefault ( model.source, Cmd.none )
            in
            ( { model | source = source, contextualOverlay = Nothing }, cmd )

        ChangeCancelReason reason ->
            let
                updateOverlay contextualOverlay =
                    case contextualOverlay of
                        CancelOverlay overlay ->
                            CancelOverlay { overlay | reason = reason }

                        _ ->
                            contextualOverlay
            in
            ( { model | contextualOverlay = model.contextualOverlay |> Maybe.map updateOverlay }, Cmd.none )

        SetWinner id winner ->
            let
                updateOverlay contextualOverlay =
                    case contextualOverlay of
                        CompleteOverlay overlay ->
                            CompleteOverlay
                                { overlay
                                    | winners =
                                        overlay.winners |> EverySet.setMembership winner id
                                }

                        _ ->
                            contextualOverlay
            in
            ( { model | contextualOverlay = model.contextualOverlay |> Maybe.map updateOverlay }, Cmd.none )

        Save ->
            case model |> diff |> Result.map encodeDiff of
                Ok encoded ->
                    let
                        method =
                            if isNew model then
                                Api.put

                            else
                                Api.post

                        betId =
                            resolveId model

                        ( source, cmd ) =
                            { path = Api.BetRoot |> Api.Bet betId |> Api.Game model.gameId
                            , body = encoded
                            , wrap = Saved betId >> wrap
                            , decoder = EditableBet.decoder
                            }
                                |> method origin
                                |> Api.getIdData betId model.source
                    in
                    ( { model | source = source }, cmd )

                Err _ ->
                    -- TODO: This should never happen because of validators, but still.
                    ( model, Cmd.none )

        Saved betId result ->
            let
                source =
                    model.source |> Api.updateIdData betId result

                redirect =
                    case result of
                        Ok _ ->
                            betId
                                |> Route.Bet model.gameId
                                |> Route.pushUrl navigationKey

                        Err _ ->
                            Cmd.none
            in
            ( { model | source = source }, redirect )


nameValidator : Validator Model
nameValidator =
    Validator.fromPredicate "Name must not be empty." (.name >> String.isEmpty)


descriptionValidator : Validator Model
descriptionValidator =
    Validator.fromPredicate "Description must not be empty." (.description >> String.isEmpty)


optionsValidator : Validator Model
optionsValidator =
    let
        resolveOptionSlug { id, name } =
            Slug.resolve Option.idFromString name id

        options =
            .options >> AssocList.values
    in
    Validator.all
        [ Validator.fromPredicate "You must have at least two options." (\m -> (m.options |> AssocList.size) < 2)
        , Validator.fromPredicate "All options must have non-empty ids."
            (options >> List.map (resolveOptionSlug >> Option.idToString) >> List.any String.isEmpty)
        , Validator.fromPredicate "All options must have non-empty names."
            (options >> List.map .name >> List.any String.isEmpty)
        , Validator.fromPredicate "All option ids must be unique."
            (options >> List.map (resolveOptionSlug >> Option.idToString) >> List.allDifferent >> not)
        ]


validator : Validator Model
validator =
    Validator.all
        [ nameValidator
        , descriptionValidator
        , optionsValidator
        ]


type alias SourceInfo msg =
    { version : Int
    , created : Html msg
    , modified : Html msg
    , author : User.SummaryWithId
    , progress : EditableBet.Progress
    }


toSourceInfo : Time.Context -> EditableBet -> SourceInfo msg
toSourceInfo time { author, created, modified, version, progress } =
    { version = version
    , created = created |> DateTime.view time Time.Absolute
    , modified = modified |> DateTime.view time Time.Absolute
    , author = author
    , progress = progress
    }


newSourceInfo : User.WithId -> SourceInfo msg
newSourceInfo localUser =
    { version = 0
    , created = Html.text "N/A (New Bet)"
    , modified = Html.text "N/A (New Bet)"
    , author = { id = localUser.id, user = User.summary localUser.user }
    , progress = EditableBet.Voting
    }


view : (Route -> msg) -> (Msg -> msg) -> Time.Context -> User.WithId -> Model -> List (Html msg)
view changeUrl wrap time localUser model =
    let
        coreContent =
            viewCoreContent changeUrl wrap time localUser model
    in
    [ instructions
    , model.source
        |> Api.idDataToData
        |> Maybe.map (Tuple.second >> Api.viewData Api.viewOrError (toSourceInfo time >> coreContent))
        |> Maybe.withDefault (coreContent (newSourceInfo localUser))
        |> Html.div [ HtmlA.class "core-content" ]
    ]


viewCoreContent : (Route -> msg) -> (Msg -> msg) -> Time.Context -> User.WithId -> Model -> SourceInfo msg -> List (Html msg)
viewCoreContent changeUrl wrap time localUser model { author, created, modified, version, progress } =
    let
        betId =
            resolveId model

        bet =
            toBet localUser.id model

        preview =
            [ Html.h3 [] [ Html.text "Preview" ]
            , Bet.view changeUrl time Nothing model.gameId "" betId bet
            ]

        progressOverlay =
            case model.contextualOverlay of
                Just overlay ->
                    let
                        ( editor, actionDetails, valid ) =
                            case overlay of
                                CompleteOverlay { winners } ->
                                    let
                                        winnerToggle ( id, option ) =
                                            let
                                                optionId =
                                                    option.id |> Slug.resolve Option.idFromString option.name
                                            in
                                            ( id
                                            , Html.li []
                                                [ Html.label [ HtmlA.class "switch" ]
                                                    [ Html.span [] [ Html.text option.name ]
                                                    , Switch.switch
                                                        (SetWinner optionId >> wrap |> Just)
                                                        (winners |> EverySet.member optionId)
                                                        |> Switch.view
                                                    ]
                                                ]
                                            )
                                    in
                                    ( [ Html.p [] [ Html.text "Select the winner(s):" ]
                                      , model.options
                                            |> AssocList.toList
                                            |> List.map winnerToggle
                                            |> HtmlK.ol []
                                      ]
                                    , { icon = Icon.check, title = "Declare Winner(s) For Bet", dangerous = False }
                                    , winners |> EverySet.isEmpty |> not
                                    )

                                CancelOverlay { reason } ->
                                    ( [ TextField.outlined "Reason for cancellation"
                                            (ChangeCancelReason >> wrap |> Just)
                                            reason
                                            |> TextField.required True
                                            |> TextField.view
                                      ]
                                    , { icon = Icon.ban, title = "Cancel & Refund Bet", dangerous = True }
                                    , reason |> String.isEmpty |> not
                                    )
                    in
                    [ [ editor
                            ++ [ Html.div [ HtmlA.class "controls" ]
                                    [ Button.text "Cancel"
                                        |> Button.button (ResolveOverlay False |> wrap |> Just)
                                        |> Button.icon [ Icon.times |> Icon.view ]
                                        |> Button.view
                                    , Html.div [ HtmlA.classList [ ( "dangerous", actionDetails.dangerous ) ] ]
                                        [ Button.filled actionDetails.title
                                            |> Button.button (ResolveOverlay True |> wrap |> Maybe.when valid)
                                            |> Button.icon [ actionDetails.icon |> Icon.view ]
                                            |> Button.view
                                        ]
                                    ]
                               ]
                            |> Html.div [ HtmlA.class "contextual-overlay" ]
                      ]
                        |> Overlay.view (False |> ResolveOverlay |> wrap)
                    ]

                Nothing ->
                    []

        isSaving =
            Api.isIdDataLoading model.source

        ifNotSaving =
            Api.ifNotIdDataLoading model.source

        ifNotNewAndNotSaving =
            Maybe.whenNot (isNew model) >> ifNotSaving

        cancel =
            Html.div [ HtmlA.class "dangerous" ]
                [ Button.filledTonal "Cancel & Refund Bet"
                    |> Button.button (Cancel |> wrap |> ifNotNewAndNotSaving)
                    |> Button.icon [ Icon.ban |> Icon.view ]
                    |> Button.view
                ]

        ( progressDescription, progressButtons ) =
            case progress of
                EditableBet.Voting ->
                    ( "Bet open for voting."
                    , [ Button.filledTonal "Lock Bet"
                            |> Button.button (SetLocked True |> wrap |> ifNotNewAndNotSaving)
                            |> Button.icon [ Icon.lock |> Icon.view ]
                            |> Button.view
                      , cancel
                      ]
                    )

                EditableBet.Locked ->
                    ( "Bet locked."
                    , [ Button.filledTonal "Unlock Bet"
                            |> Button.button (SetLocked False |> wrap |> ifNotNewAndNotSaving)
                            |> Button.icon [ Icon.unlock |> Icon.view ]
                            |> Button.view
                      , Button.filledTonal
                            "Declare Winner(s) For Bet"
                            |> Button.button (Complete |> wrap |> ifNotNewAndNotSaving)
                            |> Button.icon [ Icon.check |> Icon.view ]
                            |> Button.view
                      , cancel
                      ]
                    )

                EditableBet.Complete _ ->
                    ( "Bet complete."
                    , [ Button.filledTonal "Revert Complete"
                            |> Button.button (RevertComplete |> wrap |> ifNotNewAndNotSaving)
                            |> Button.icon [ Icon.undo |> Icon.view ]
                            |> Button.view
                      ]
                    )

                EditableBet.Cancelled _ ->
                    ( "Bet cancelled."
                    , [ Button.filledTonal "Revert Cancel"
                            |> Button.button (RevertCancel |> wrap |> ifNotNewAndNotSaving)
                            |> Button.icon [ Icon.undo |> Icon.view ]
                            |> Button.view
                      ]
                    )
    in
    Html.div [ HtmlA.id "bet-editor", HtmlA.class "editor" ]
        [ Html.h3 [] [ Html.text "Metadata" ]
        , Html.div [ HtmlA.class "metadata" ]
            [ Html.div [ HtmlA.class "author" ]
                [ Html.text "Author: "
                , User.viewLink User.Full author.id author.user
                ]
            , Html.div [ HtmlA.class "created" ] [ Html.text "Created: ", created ]
            , Html.div [ HtmlA.class "modified" ] [ Html.text "Last Modified: ", modified ]
            , Html.div [ HtmlA.class "version" ] [ Html.text "Version: ", version |> String.fromInt |> Html.text ]
            ]
        , Html.h3 [] [ Html.text "Progress" ]
        , Html.p [] [ Html.text progressDescription ]
        , Html.div [ HtmlA.class "progress" ] (progressButtons ++ progressOverlay)
        , Html.h3 [] [ Html.text "Edit" ]
        , Slug.view Bet.idFromString Bet.idToString (SetId >> wrap |> Just |> ifNotSaving) model.name model.id
        , TextField.outlined "Name" (SetName >> wrap |> Just |> ifNotSaving) model.name
            |> TextField.required True
            |> Validator.textFieldError nameValidator model
            |> TextField.view
        , TextField.outlined "Description" (SetDescription >> wrap |> Maybe.whenNot isSaving) model.description
            |> TextField.textArea
            |> TextField.required True
            |> Validator.textFieldError descriptionValidator model
            |> TextField.view
        , LockMoment.selector (EditLockMoments >> wrap |> Just |> ifNotSaving)
            (model |> lockMomentContext)
            (SetLockMoment >> wrap |> Just |> ifNotSaving)
            model.lockMoment
        , Html.label [ HtmlA.class "switch" ]
            [ Html.span [] [ Html.text "Is Spoiler" ]
            , Switch.switch (SetSpoiler >> wrap |> Just |> ifNotSaving) model.spoiler
                |> Switch.view
            ]
        , model.options
            |> AssocList.toList
            |> List.map (viewOption (wrap |> Just |> ifNotSaving))
            |> HtmlK.ol []
        , Html.div [ HtmlA.class "option-controls" ]
            [ Button.text "Add"
                |> Button.button (NewOption |> wrap |> Just |> ifNotSaving)
                |> Button.icon [ Icon.plus |> Icon.view ]
                |> Button.view
            ]
        , Validator.view optionsValidator model
        , Html.div [ HtmlA.class "controls" ]
            [ Button.text "Reset"
                |> Button.button (Reset |> wrap |> Just |> ifNotSaving)
                |> Button.icon [ Icon.undo |> Icon.view ]
                |> Button.view
            , Button.filled "Save"
                |> Button.button (Save |> wrap |> Validator.whenValid validator model |> ifNotSaving)
                |> Button.icon [ Icon.save |> Icon.view ]
                |> Button.view
            ]
        ]
        :: Html.div [ HtmlA.class "preview" ] preview
        :: LockMoment.viewEditor (EditLockMoments >> wrap) (model |> lockMomentContext) model.lockMomentEditor


instructions : Html msg
instructions =
    Html.div [ HtmlA.class "instructions" ]
        [ Html.p [] [ Html.text "Rules for bets:" ]
        , Html.ul []
            [ Html.li [] [ Html.text "Always mark a bet as a spoiler if needed. Err on the side of caution here." ]
            , Html.li [] [ Html.text "No bets that attack people, etc..." ]
            , Html.li [] [ Html.text "No gaming the bets for personal gain." ]
            , Html.li [] [ Html.text "If Joe ever gets troubled by a bet or anything, pull it. The site is for fun, if it ever causes problems, it isn't worth it." ]
            ]
        , Html.p [] [ Html.text "Hopefully these are obvious." ]
        , Html.p [] [ Html.text "Advice for good bets:" ]
        , Html.ul []
            [ Html.li [] [ Html.text "Wait to complete bets until the outcome is set in stone, make sure Joe doesn't reload or whatever. Rolling back bets is a pain, so try not to get it wrong." ]
            , Html.li [] [ Html.text "Avoid yes/no bets unless there isn't a way to make it more interesting and the bet is really core." ]
            , Html.li [] [ Html.text "Avoid subjective results wherever possible." ]
            , Html.li [] [ Html.text "Set the lock moment to as late as possible, but early enough that it can be locked before people change their bet because they can see which way the bet is going." ]
            , Html.li [] [ Html.text "Try to make sure options are exhaustive, where possible. If not, detail explicitly what will happen (e.g: the bet will be cancelled)." ]
            , Html.li [] [ Html.text "Try to make it very clear how the bet works, define things clearly and rule lawyer a bit so people can't get upset." ]
            , Html.li [] [ Html.text "Avoid bets that might be controversial or divisive in an unfun way." ]
            , Html.li [] [ Html.text "Avoid bets that might seriously encourage backseating or people trying to push Joe to do something." ]
            , Html.li [] [ Html.text "Avoid bets that rely on Joe expressing a preference or something that places a burden on him to provide an opinion that he may not apply." ]
            , Html.li [] [ Html.text "Really short term bets aren't a great fit for JASB. They can be fun occasionally but try to aim for longer-term stuff (at least a stream-length bet)." ]
            , Html.li [] [ Html.text "Try to avoid having *way* too many options. Over 20 or so starts to get really unwieldy and increases the chance that no one will win at all." ]
            ]
        , Html.p [] [ Html.text "None of the advice is a hard rule, and some bets may be worth doing even if they cross these, but try to keep them in mind and follow them if in doubt." ]
        ]


optionNameValidator : Validator String
optionNameValidator =
    Validator.fromPredicate "Name must not be empty." String.isEmpty


viewOption : Maybe (Msg -> msg) -> ( String, OptionEditor ) -> ( String, Html msg )
viewOption maybeWrap ( internalId, { id, name, image, order } ) =
    let
        wrapChangeOption =
            ChangeOption internalId

        wrapIfGiven value =
            maybeWrap |> Maybe.map (\w -> value |> wrapChangeOption |> w)

        applyWrapIfGiven value =
            maybeWrap |> Maybe.map (\w -> value >> wrapChangeOption >> w)

        content =
            Html.li [ HtmlA.class "option-editor" ]
                [ Html.div [ HtmlA.class "order" ]
                    [ IconButton.icon (Icon.arrowUp |> Icon.view) "Move Up"
                        |> IconButton.button (order - 1 |> String.fromInt |> SetOptionOrder |> wrapIfGiven)
                        |> IconButton.view
                    , TextField.outlined "Order" (SetOptionOrder |> applyWrapIfGiven) (String.fromInt order)
                        |> TextField.view
                    , IconButton.icon (Icon.arrowDown |> Icon.view) "Move Down"
                        |> IconButton.button (order + 1 |> String.fromInt |> SetOptionOrder |> wrapIfGiven)
                        |> IconButton.view
                    ]
                , Html.div [ HtmlA.class "details" ]
                    [ Html.div [ HtmlA.class "inline" ]
                        [ Html.span [ HtmlA.class "fullwidth" ]
                            [ Slug.view Option.idFromString Option.idToString (SetOptionId |> applyWrapIfGiven) name id ]
                        , IconButton.icon (Icon.trash |> Icon.view) "Delete"
                            |> IconButton.button (DeleteOption |> wrapIfGiven)
                            |> IconButton.view
                        ]
                    , TextField.outlined "Name" (SetOptionName |> applyWrapIfGiven) name
                        |> TextField.required True
                        |> Validator.textFieldError optionNameValidator name
                        |> TextField.view
                    , Uploader.view (OptionImageUploaderMsg |> applyWrapIfGiven) imageUploaderModel image
                    ]
                ]
    in
    ( internalId, content )


imageUploaderModel : Uploader.Model
imageUploaderModel =
    { label = "Image"
    , types = [ "image/*" ]
    }
