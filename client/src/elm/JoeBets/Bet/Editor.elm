module JoeBets.Bet.Editor exposing
    ( empty
    , isNew
    , load
    , update
    , view
    )

import AssocList
import EverySet as EverySet
import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Events as HtmlE
import Html.Keyed as HtmlK
import Http
import JoeBets.Api as Api
import JoeBets.Bet as Bet
import JoeBets.Bet.Editor.EditableBet as EditableBet exposing (EditableBet)
import JoeBets.Bet.Editor.Model exposing (..)
import JoeBets.Bet.Model as Bet
import JoeBets.Bet.Option as Option
import JoeBets.Editing.Slug as Slug
import JoeBets.Editing.Uploader as Uploader
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game
import JoeBets.Page.Edit.Model as Edit
import JoeBets.Page.Edit.Validator as Validator exposing (Validator)
import JoeBets.User as User
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Model as User
import Json.Encode as JsonE
import List.Extra as List
import Material.Button as Button
import Material.IconButton as IconButton
import Material.Switch as Switch
import Material.TextArea as TextArea
import Material.TextField as TextField
import Time.DateTime as DateTime
import Time.Model as Time
import Util.AssocList as AssocList
import Util.EverySet as EverySet
import Util.Maybe as Maybe
import Util.RemoteData as RemoteData


type alias Parent a =
    { a
        | origin : String
    }


empty : User.Id -> Bool -> Game.Id -> Edit.EditMode -> Model
empty _ isMod gameId editMode =
    let
        ( source, id ) =
            case editMode of
                Edit.Edit toEditId ->
                    ( Just { id = toEditId, bet = RemoteData.Missing }, Slug.Locked toEditId )

                _ ->
                    ( Nothing, Slug.Auto )

        mode =
            if not isMod || editMode == Edit.Suggest then
                EditSuggestion

            else
                EditBet
    in
    { mode = mode
    , source = source
    , gameId = gameId
    , id = id
    , name = ""
    , description = ""
    , spoiler = True
    , locksWhen = ""
    , options = AssocList.empty
    , contextualOverlay = Nothing
    , internalIdCounter = 0
    }


isNew : Model -> Bool
isNew { source } =
    source == Nothing


load : String -> User.WithId -> (Msg -> msg) -> Game.Id -> Edit.EditMode -> ( Model, Cmd msg )
load origin localUser wrap gameId editMode =
    let
        isMod =
            Auth.isMod gameId (Just localUser)

        model =
            empty localUser.id isMod gameId editMode

        cmd =
            case editMode of
                Edit.Edit id ->
                    Api.get origin
                        { path = Api.Game gameId (Api.Bet id Api.Edit)
                        , expect = Http.expectJson (Load gameId id >> wrap) EditableBet.decoder
                        }

                _ ->
                    Cmd.none
    in
    ( model, cmd )


fromSource : Bet.Id -> EditableBet -> Model -> Model
fromSource bet editableBet model =
    { model
        | id = bet |> Slug.Locked
        , name = editableBet.name
        , description = editableBet.description
        , spoiler = editableBet.spoiler
        , locksWhen = editableBet.locksWhen
        , options =
            editableBet.options
                |> AssocList.toList
                |> List.map initOptionFromEditable
                |> AssocList.fromList
                |> AssocList.sortBy (\_ v -> v.order)
        , source = Just { id = bet, bet = RemoteData.Loaded editableBet }
    }


update : (Msg -> msg) -> User.WithId -> Msg -> Parent a -> Model -> ( Model, Cmd msg )
update wrap localUser msg ({ origin } as parent) model =
    case msg of
        Load game bet result ->
            case result of
                Ok editableBet ->
                    if model.gameId == game && (model.source |> Maybe.map .id) == Just bet then
                        ( model |> fromSource bet editableBet
                        , Cmd.none
                        )

                    else
                        ( model, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        Reset ->
            case model.source of
                Just { id, bet } ->
                    case bet |> RemoteData.toMaybe of
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
                    ( empty localUser.id False model.gameId editMode
                    , Cmd.none
                    )

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

        SetLocksWhen locksWhen ->
            ( { model | locksWhen = locksWhen }, Cmd.none )

        SetLocked locked ->
            case model.source |> Maybe.andThen (.bet >> RemoteData.toMaybe) of
                Just bet ->
                    let
                        action =
                            if locked then
                                Api.Lock

                            else
                                Api.Unlock

                        betId =
                            resolveId model

                        request =
                            Api.post origin
                                { path = action |> Api.Bet betId |> Api.Game model.gameId
                                , body = [ ( "version", JsonE.int bet.version ) ] |> JsonE.object |> Http.jsonBody
                                , expect = Http.expectJson (Load model.gameId betId >> wrap) EditableBet.decoder
                                }
                    in
                    ( model, request )

                Nothing ->
                    ( model, Cmd.none )

        Complete ->
            ( { model | contextualOverlay = { winners = EverySet.empty } |> CompleteOverlay |> Just }, Cmd.none )

        RevertComplete ->
            case model.source |> Maybe.andThen (.bet >> RemoteData.toMaybe) of
                Just bet ->
                    let
                        betId =
                            resolveId model

                        request =
                            Api.post origin
                                { path = Api.RevertComplete |> Api.Bet betId |> Api.Game model.gameId
                                , body = [ ( "version", JsonE.int bet.version ) ] |> JsonE.object |> Http.jsonBody
                                , expect = Http.expectJson (Load model.gameId betId >> wrap) EditableBet.decoder
                                }
                    in
                    ( model, request )

                Nothing ->
                    ( model, Cmd.none )

        Cancel ->
            ( { model | contextualOverlay = { reason = "" } |> CancelOverlay |> Just }, Cmd.none )

        RevertCancel ->
            case model.source |> Maybe.andThen (.bet >> RemoteData.toMaybe) of
                Just bet ->
                    let
                        betId =
                            resolveId model

                        request =
                            Api.post origin
                                { path = Api.RevertCancel |> Api.Bet betId |> Api.Game model.gameId
                                , body = [ ( "version", JsonE.int bet.version ) ] |> JsonE.object |> Http.jsonBody
                                , expect = Http.expectJson (Load model.gameId betId >> wrap) EditableBet.decoder
                                }
                    in
                    ( model, request )

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

                                replaceImageInOption =
                                    { option | image = image } |> Just |> always

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
                                        |> List.indexedMap (\o ( id, _ ) -> ( id, o ))
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
                                |> AssocList.indexedMap (\i _ o -> { o | order = i })
                    in
                    ( { model | options = newOptions }, Cmd.none )

        ResolveOverlay commit ->
            let
                cmd =
                    if commit then
                        case model.contextualOverlay of
                            Just (CancelOverlay { reason }) ->
                                if String.isEmpty reason then
                                    Cmd.none

                                else
                                    let
                                        body bet =
                                            { version = bet.version, reason = reason }
                                                |> encodeCancelAction
                                    in
                                    makeChangeRequest wrap
                                        origin
                                        Api.Cancel
                                        body
                                        model

                            Just (CompleteOverlay { winners }) ->
                                if EverySet.isEmpty winners then
                                    Cmd.none

                                else
                                    let
                                        body bet =
                                            { version = bet.version, winners = winners }
                                                |> encodeCompleteAction
                                    in
                                    makeChangeRequest wrap
                                        origin
                                        Api.Complete
                                        body
                                        model

                            Nothing ->
                                Cmd.none

                    else
                        Cmd.none
            in
            ( { model | contextualOverlay = Nothing }, cmd )

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


nameValidator : Validator Model
nameValidator =
    Validator.fromPredicate "Name must not be empty." (.name >> String.isEmpty)


descriptionValidator : Validator Model
descriptionValidator =
    Validator.fromPredicate "Description must not be empty." (.description >> String.isEmpty)


locksWhenValidator : Validator Model
locksWhenValidator =
    Validator.fromPredicate "Lock moment must not be empty." (.locksWhen >> String.isEmpty)


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


view : msg -> (Msg -> msg) -> Time.Context -> User.WithId -> Model -> List (Html msg)
view save wrap time localUser model =
    let
        betId =
            resolveId model

        bet =
            toBet localUser.id model

        preview =
            [ Html.h3 [] [ Html.text "Preview" ], Bet.view time Nothing model.gameId "" betId bet ]

        summarise { id, user } =
            { id = id, summary = User.summary user }

        maybeSource =
            model.source
                |> Maybe.andThen (.bet >> RemoteData.toMaybe)

        author =
            maybeSource
                |> Maybe.map .author
                |> Maybe.withDefault (summarise localUser)

        textField name type_ value action attrs =
            TextField.viewWithAttrs name type_ value action (HtmlA.attribute "outlined" "" :: attrs)

        progress =
            maybeSource |> Maybe.map .progress |> Maybe.withDefault EditableBet.Voting

        cancel =
            Html.div [ HtmlA.class "dangerous" ]
                [ Button.view Button.Raised
                    Button.Padded
                    "Cancel & Refund Bet"
                    (Icon.ban |> Icon.viewIcon |> Just)
                    (Cancel |> wrap |> Just)
                ]

        ( progressDescription, progressButtons ) =
            case progress of
                EditableBet.Voting ->
                    ( "Bet open for voting."
                    , [ Button.view
                            Button.Raised
                            Button.Padded
                            "Lock Bet"
                            (Icon.lock |> Icon.viewIcon |> Just)
                            (SetLocked True |> wrap |> Just)
                      , cancel
                      ]
                    )

                EditableBet.Locked ->
                    ( "Bet locked."
                    , [ Button.view
                            Button.Raised
                            Button.Padded
                            "Unlock Bet"
                            (Icon.unlock |> Icon.viewIcon |> Just)
                            (SetLocked False |> wrap |> Just)
                      , Button.view Button.Raised
                            Button.Padded
                            "Declare Winner(s) For Bet"
                            (Icon.check |> Icon.viewIcon |> Just)
                            (Complete |> wrap |> Just)
                      , cancel
                      ]
                    )

                EditableBet.Complete _ ->
                    ( "Bet complete."
                    , [ Button.view
                            Button.Raised
                            Button.Padded
                            "Revert Complete"
                            (Icon.undo |> Icon.viewIcon |> Just)
                            (RevertComplete |> wrap |> Just)
                      ]
                    )

                EditableBet.Cancelled _ ->
                    ( "Bet cancelled."
                    , [ Button.view
                            Button.Raised
                            Button.Padded
                            "Revert Cancel"
                            (Icon.undo |> Icon.viewIcon |> Just)
                            (RevertCancel |> wrap |> Just)
                      ]
                    )

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
                                                [ Switch.view (Html.text option.name)
                                                    (winners |> EverySet.member optionId)
                                                    (SetWinner optionId >> wrap |> Just)
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
                                    ( [ textField "Reason for cancellation"
                                            TextField.Text
                                            reason
                                            (ChangeCancelReason >> wrap |> Just)
                                            [ HtmlA.required True ]
                                      ]
                                    , { icon = Icon.ban, title = "Cancel & Refund Bet", dangerous = True }
                                    , reason |> String.isEmpty |> not
                                    )
                    in
                    [ Html.div [ HtmlA.class "overlay" ]
                        [ Html.div [ HtmlA.class "contextual-overlay" ]
                            [ Html.div [] editor
                            , Html.div [ HtmlA.class "actions" ]
                                [ Button.view Button.Standard
                                    Button.Padded
                                    "Cancel"
                                    (Icon.times |> Icon.present |> Icon.view |> Just)
                                    (ResolveOverlay False |> wrap |> Just)
                                , Html.div [ HtmlA.classList [ ( "dangerous", actionDetails.dangerous ) ] ]
                                    [ Button.view
                                        Button.Raised
                                        Button.Padded
                                        actionDetails.title
                                        (actionDetails.icon |> Icon.present |> Icon.view |> Just)
                                        (ResolveOverlay True |> wrap |> Maybe.when valid)
                                    ]
                                ]
                            ]
                        ]
                    ]

                Nothing ->
                    []
    in
    [ instructions
    , Html.div [ HtmlA.class "core-content" ]
        [ Html.div [ HtmlA.id "bet-editor", HtmlA.class "editor" ]
            [ Html.h3 [] [ Html.text "Metadata" ]
            , Html.div [ HtmlA.class "metadata" ]
                [ Html.div [ HtmlA.class "author" ]
                    [ Html.text "Author: "
                    , User.viewLink User.Full author.id author.summary
                    ]
                , Html.div [ HtmlA.class "created" ]
                    [ Html.text "Created: "
                    , maybeSource |> Maybe.map (.created >> DateTime.view time Time.Absolute) |> Maybe.withDefault (Html.text "- (New)")
                    ]
                , Html.div [ HtmlA.class "modified" ]
                    [ Html.text "Last Modified: "
                    , maybeSource |> Maybe.map (.modified >> DateTime.view time Time.Absolute) |> Maybe.withDefault (Html.text "- (New)")
                    ]
                , Html.div [ HtmlA.class "modified" ]
                    [ Html.text "Version: "
                    , maybeSource |> Maybe.map (.version >> String.fromInt) |> Maybe.withDefault "- (New)" |> Html.text
                    ]
                ]
            , Html.h3 [] [ Html.text "Progress" ]
            , Html.p [] [ Html.text progressDescription ]
            , Html.div [ HtmlA.class "progress" ] (progressButtons ++ progressOverlay)
            , Html.h3 [] [ Html.text "Edit" ]
            , Slug.view Bet.idFromString Bet.idToString (SetId >> wrap) model.name model.id
            , textField "Name" TextField.Text model.name (SetName >> wrap |> Just) [ HtmlA.required True ]
            , Validator.view nameValidator model
            , TextArea.view
                [ "Description" |> HtmlA.attribute "label"
                , SetDescription >> wrap |> HtmlE.onInput
                , HtmlA.required True
                , HtmlA.attribute "outlined" ""
                , HtmlA.value model.description
                ]
                []
            , Validator.view descriptionValidator model
            , textField "Lock Moment" TextField.Text model.locksWhen (SetLocksWhen >> wrap |> Just) [ HtmlA.required True ]
            , Validator.view locksWhenValidator model
            , Switch.view (Html.text "Spoiler") model.spoiler (SetSpoiler >> wrap |> Just)
            , model.options
                |> AssocList.toList
                |> List.map (viewOption wrap)
                |> HtmlK.ol []
            , Html.div [ HtmlA.class "option-controls" ]
                [ Button.view Button.Standard
                    Button.Padded
                    "Add"
                    (Icon.plus |> Icon.present |> Icon.view |> Just)
                    (NewOption |> wrap |> Just)
                ]
            , Validator.view optionsValidator model
            , Html.div [ HtmlA.class "controls" ]
                [ Button.view Button.Standard
                    Button.Padded
                    "Reset"
                    (Icon.undo |> Icon.present |> Icon.view |> Just)
                    (Reset |> wrap |> Just)
                , Button.view Button.Raised
                    Button.Padded
                    "Save"
                    (Icon.save |> Icon.present |> Icon.view |> Just)
                    (save |> Validator.whenValid validator model)
                ]
            ]
        , Html.div [ HtmlA.class "preview" ] preview
        ]
    ]


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


viewOption : (Msg -> msg) -> ( String, OptionEditor ) -> ( String, Html msg )
viewOption wrap ( internalId, { id, name, image, order } ) =
    let
        wrapChangeOption =
            ChangeOption internalId >> wrap

        textField label type_ value action attrs =
            TextField.viewWithAttrs label type_ value action (HtmlA.attribute "outlined" "" :: attrs)

        content =
            Html.li [ HtmlA.class "option-editor" ]
                [ Html.div [ HtmlA.class "order" ]
                    [ IconButton.view (Icon.arrowUp |> Icon.present |> Icon.view) "Move Up" (order - 1 |> String.fromInt |> SetOptionOrder |> wrapChangeOption |> Just)
                    , textField "Order" TextField.Number (String.fromInt order) (SetOptionOrder >> wrapChangeOption |> Just) []
                    , IconButton.view (Icon.arrowDown |> Icon.present |> Icon.view) "Move Down" (order + 1 |> String.fromInt |> SetOptionOrder |> wrapChangeOption |> Just)
                    ]
                , Html.div [ HtmlA.class "details" ]
                    [ Html.div [ HtmlA.class "inline" ]
                        [ Html.span [ HtmlA.class "fullwidth" ]
                            [ Slug.view Option.idFromString Option.idToString (SetOptionId >> wrapChangeOption) name id ]
                        , IconButton.view (Icon.trash |> Icon.present |> Icon.view) "Delete" (DeleteOption |> wrapChangeOption |> Just)
                        ]
                    , textField "Name" TextField.Text name (SetOptionName >> wrapChangeOption |> Just) [ HtmlA.required True ]
                    , Validator.view optionNameValidator name
                    , Uploader.view (OptionImageUploaderMsg >> wrapChangeOption) imageUploaderModel image
                    ]
                ]
    in
    ( internalId, content )


makeChangeRequest wrap origin path body ({ gameId, source } as model) =
    case source |> Maybe.andThen (.bet >> RemoteData.toMaybe) of
        Just bet ->
            let
                betId =
                    resolveId model

                request =
                    Api.post origin
                        { path = path |> Api.Bet betId |> Api.Game gameId
                        , body = body bet |> Http.jsonBody
                        , expect = Http.expectJson (Load gameId betId >> wrap) EditableBet.decoder
                        }
            in
            request

        Nothing ->
            Cmd.none


imageUploaderModel : Uploader.Model
imageUploaderModel =
    { label = "Image"
    , types = [ "image/*" ]
    }
