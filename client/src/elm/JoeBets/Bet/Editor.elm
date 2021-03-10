module JoeBets.Bet.Editor exposing
    ( load
    , toBet
    , update
    , view
    )

import AssocList
import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Events as HtmlE
import Http
import JoeBets.Api as Api
import JoeBets.Bet as Bet
import JoeBets.Bet.Editor.Model exposing (..)
import JoeBets.Bet.Editor.OptionEditor as OptionEditor
import JoeBets.Bet.Editor.ProgressEditor as ProgressEditor
import JoeBets.Bet.Model as Bet exposing (Bet)
import JoeBets.Bet.Option as Option exposing (Option)
import JoeBets.Game.Model as Game exposing (Game)
import JoeBets.Page.Bet.Model as Bet
import JoeBets.Page.Edit.Validator as Validator exposing (Validator)
import JoeBets.User.Model as User
import List.Extra as List
import Material.Button as Button
import Material.Switch as Switch
import Material.TextArea as TextArea
import Material.TextField as TextField
import Util.Maybe as Maybe
import Util.RemoteData as RemoteData
import Util.Url as Url


empty : Game.Id -> Maybe Bet.Id -> Model
empty gameId maybeBet =
    { source = maybeBet |> Maybe.map (\id -> ( id, RemoteData.Missing ))
    , gameId = gameId
    , name = ""
    , description = ""
    , progress = ProgressEditor.init
    , spoiler = True
    , options = []
    }


load : String -> (Msg -> msg) -> Game.Id -> Maybe Bet.Id -> ( Model, Cmd msg )
load origin wrap gameId maybeBet =
    let
        model =
            empty gameId maybeBet

        cmd =
            case maybeBet of
                Just id ->
                    Api.get origin
                        { path = [ "game", gameId |> Game.idToString, id |> Bet.idToString ]
                        , expect = Http.expectJson (Load gameId id >> wrap) Bet.gameAndBetDecoder
                        }

                Nothing ->
                    Cmd.none
    in
    ( model, cmd )


fromBet : Game.Id -> Bet.Id -> Bet.GameAndBet -> Model
fromBet gameId betId ({ bet } as gameAndBet) =
    { source = Just ( betId, RemoteData.Loaded gameAndBet )
    , gameId = gameId
    , name = bet.name
    , description = bet.description
    , progress = ProgressEditor.fromBet bet
    , spoiler = bet.spoiler
    , options = bet.options |> AssocList.toList |> List.map OptionEditor.fromOption
    }


update : Msg -> Model -> Model
update msg model =
    case msg of
        Load gameId id result ->
            case result of
                Ok bet ->
                    fromBet gameId id bet

                Err error ->
                    { model | source = Just ( id, RemoteData.Failed error ) }

        Reset ->
            case model.source of
                Just ( betId, data ) ->
                    case data of
                        RemoteData.Loaded bet ->
                            fromBet model.gameId betId bet

                        _ ->
                            model

                Nothing ->
                    empty model.gameId Nothing

        ChangeName name ->
            { model | name = name }

        ChangeDescription description ->
            { model | description = description }

        ChangeSpoiler spoiler ->
            { model | spoiler = spoiler }

        AddOption ->
            { model | options = model.options ++ [ OptionEditor.new ] }

        DeleteOption index ->
            { model | options = List.take index model.options ++ List.drop (index + 1) model.options }

        OptionEditorMsg targetIndex optionEditorMsg ->
            let
                updateAtIndex index =
                    if index == targetIndex then
                        OptionEditor.update optionEditorMsg

                    else
                        identity
            in
            { model | options = model.options |> List.indexedMap updateAtIndex }

        ReorderOption from to ->
            let
                oldProgress =
                    model.progress

                adjustForMove oldWinner =
                    if oldWinner == from then
                        to

                    else if oldWinner == to then
                        from

                    else
                        oldWinner

                options =
                    model.options |> List.swapAt from to

                progress =
                    { oldProgress | winner = oldProgress.winner |> Maybe.map adjustForMove }
            in
            { model | options = options, progress = progress }

        ProgressEditorMsg progressEditorMsg ->
            { model | progress = ProgressEditor.update progressEditorMsg model.progress }

        NoOp ->
            model


toBet : User.Id -> Model -> ( Bet.Id, Bet )
toBet localUser model =
    let
        optionToEntry optionEditorModel =
            let
                ( id, option ) =
                    optionEditorModel |> OptionEditor.toOption
            in
            ( id, option )

        options =
            model.options |> List.map optionToEntry |> List.reverse |> AssocList.fromList
    in
    ( model.source
        |> Maybe.map Tuple.first
        |> Maybe.withDefault (model.name |> Url.slugify |> Bet.idFromString)
    , Bet model.name
        model.description
        model.spoiler
        (model.progress |> ProgressEditor.toProgress localUser options)
        options
    )


nameValidator : Validator Model
nameValidator =
    Validator.fromPredicate "Name must not be empty." (.name >> String.isEmpty)


descriptionValidator : Validator Model
descriptionValidator =
    Validator.fromPredicate "Description must not be empty." (.description >> String.isEmpty)


optionsValidator : Validator Model
optionsValidator =
    Validator.all
        [ Validator.fromPredicate "You must have at least two options." (\m -> (m.options |> List.length) < 2)
        , Validator.fromPredicate "All options must have non-empty ids."
            (.options >> List.map (OptionEditor.resolveId >> Option.idToString) >> List.any String.isEmpty)
        , Validator.fromPredicate "All option ids must be unique."
            (.options >> List.map (OptionEditor.resolveId >> Option.idToString) >> List.allDifferent >> not)
        ]


validator : AssocList.Dict Option.Id Option -> Validator Model
validator options =
    Validator.all
        [ nameValidator
        , descriptionValidator
        , ProgressEditor.validator options |> Validator.map .progress
        , OptionEditor.validator |> Validator.list |> Validator.map .options
        , optionsValidator
        ]


view : msg -> (Msg -> msg) -> User.WithId -> Model -> List (Html msg)
view save wrap localUser model =
    let
        body () =
            let
                ( id, bet ) =
                    toBet localUser.id model

                preview =
                    [ Bet.view Nothing model.gameId "" id bet ]

                textField name type_ value action attrs =
                    TextField.viewWithAttrs name type_ value action (HtmlA.attribute "outlined" "" :: attrs)

                total =
                    model.options |> List.length

                reorderBy index amount =
                    let
                        to =
                            index + amount
                    in
                    ReorderOption index to |> wrap |> Maybe.when (to >= 0 && to < total)

                viewOption index =
                    OptionEditor.view
                        (index |> DeleteOption |> wrap)
                        (OptionEditorMsg index >> wrap)
                        (reorderBy index)
                        (ProgressEditorMsg >> wrap)
                        model.progress
                        index

                sourceState =
                    model.source
                        |> Maybe.andThen (Tuple.second >> RemoteData.toMaybe)
                        |> Maybe.map (.bet >> ProgressEditor.fromBet >> .state)
            in
            [ Html.div [ HtmlA.class "core-content" ]
                [ Html.div [ HtmlA.class "editor" ]
                    [ textField "Id" TextField.Text (id |> Bet.idToString) Nothing []
                    , textField "Name" TextField.Text model.name (ChangeName >> wrap |> Just) [ HtmlA.required True ]
                    , Validator.view nameValidator model
                    , TextArea.view
                        [ "Description" |> HtmlA.attribute "label"
                        , ChangeDescription >> wrap |> HtmlE.onInput
                        , HtmlA.required True
                        , HtmlA.attribute "outlined" ""
                        , HtmlA.value model.description
                        ]
                        []
                    , Validator.view descriptionValidator model
                    , Switch.view (Html.text "Spoiler") model.spoiler (ChangeSpoiler >> wrap |> Just)
                    , ProgressEditor.view (ProgressEditorMsg >> wrap) localUser model.gameId sourceState bet.options model.progress
                    , model.options |> List.indexedMap viewOption |> Html.ol []
                    , Html.div [ HtmlA.class "option-controls" ]
                        [ Button.view Button.Standard
                            Button.Padded
                            "Add"
                            (Icon.plus |> Icon.present |> Icon.view |> Just)
                            (AddOption |> wrap |> Just)
                        ]
                    , Validator.view optionsValidator model
                    ]
                , Html.div [ HtmlA.class "preview" ] preview
                ]
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
                    (save |> Validator.whenValid (validator bet.options) model)
                ]
            ]
    in
    model.source
        |> Maybe.map Tuple.second
        |> Maybe.map (RemoteData.map (always ()))
        |> Maybe.withDefault (RemoteData.Loaded ())
        |> RemoteData.view body
