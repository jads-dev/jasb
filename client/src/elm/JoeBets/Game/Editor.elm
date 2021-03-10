module JoeBets.Game.Editor exposing
    ( load
    , toGame
    , update
    , view
    )

import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Http
import JoeBets.Api as Api
import JoeBets.Game as Game
import JoeBets.Game.Editor.Model exposing (..)
import JoeBets.Game.Model as Game exposing (Game)
import JoeBets.Page.Edit.DateTime as DateTime
import JoeBets.Page.Edit.Validator as Validator exposing (Validator)
import JoeBets.User.Auth.Model as Auth
import Json.Decode as Json
import Material.Button as Button
import Material.TextField as TextField
import Time
import Util.RemoteData as RemoteData
import Util.Url as Url


type alias Parent a =
    { a
        | zone : Time.Zone
        , time : Time.Posix
        , auth : Auth.Model
    }


empty : Maybe Game.Id -> Model
empty maybeGameId =
    { source = maybeGameId |> Maybe.map (\id -> ( id, RemoteData.Missing ))
    , name = ""
    , cover = ""
    , bets = 0
    , start = DateTime.init
    , finish = DateTime.init
    }


load : String -> (Msg -> msg) -> Maybe Game.Id -> ( Model, Cmd msg )
load origin wrap maybeGameId =
    let
        model =
            empty maybeGameId

        cmd =
            case maybeGameId of
                Just id ->
                    Api.get origin
                        { path = [ "game", id |> Game.idToString ]
                        , expect = Http.expectJson (Load id >> wrap) (Json.field "game" Game.decoder)
                        }

                Nothing ->
                    Cmd.none
    in
    ( model, cmd )


fromGame : Game.Id -> Game -> Model
fromGame id game =
    let
        ( startPosix, finishPosix ) =
            case game.progress of
                Game.Future _ ->
                    ( Nothing, Nothing )

                Game.Current { start } ->
                    ( Just start, Nothing )

                Game.Finished { start, finish } ->
                    ( Just start, Just finish )

        fromPosix =
            Maybe.map DateTime.fromPosix >> Maybe.withDefault DateTime.init
    in
    { source = Just ( id, RemoteData.Loaded game )
    , name = game.name
    , cover = game.cover
    , bets = game.bets
    , start = fromPosix startPosix
    , finish = fromPosix finishPosix
    }


update : Msg -> Model -> Model
update msg model =
    case msg of
        Load id result ->
            case result of
                Ok game ->
                    fromGame id game

                Err error ->
                    { model | source = Just ( id, RemoteData.Failed error ) }

        Reset ->
            case model.source of
                Just ( gameId, data ) ->
                    case data of
                        RemoteData.Loaded game ->
                            fromGame gameId game

                        _ ->
                            model

                Nothing ->
                    empty Nothing

        ChangeName name ->
            { model | name = name }

        ChangeCover cover ->
            { model | cover = cover }

        ChangeStart start ->
            { model | start = model.start |> DateTime.update start }

        ChangeFinish finish ->
            { model | finish = model.finish |> DateTime.update finish }


toGame : Model -> ( Game.Id, Game )
toGame model =
    let
        progress =
            case model.start |> DateTime.toPosix of
                Ok start ->
                    case model.finish |> DateTime.toPosix of
                        Ok finish ->
                            { start = start, finish = finish } |> Game.Finished

                        Err _ ->
                            { start = start } |> Game.Current

                Err _ ->
                    case model.finish |> DateTime.toPosix of
                        Ok _ ->
                            {} |> Game.Future

                        Err _ ->
                            {} |> Game.Future
    in
    ( model.source
        |> Maybe.map Tuple.first
        |> Maybe.withDefault (model.name |> Url.slugify |> Game.idFromString)
    , Game model.name model.cover model.bets progress
    )


nameValidator : Validator Model
nameValidator =
    Validator.fromPredicate "Name must not be empty." (.name >> String.isEmpty)


coverValidator : Validator Model
coverValidator =
    Validator.fromPredicate "Cover must not be empty." (.cover >> String.isEmpty)


startValidator : Validator Model
startValidator model =
    let
        startGiven =
            Validator.map .start DateTime.notEmptyValidator

        finishGiven =
            Validator.map .finish DateTime.notEmptyValidator
    in
    if Validator.valid finishGiven model && (Validator.valid startGiven model |> not) then
        [ "A start must be given if a finish is." ]

    else
        Validator.map .start DateTime.validIfGivenValidator model


finishValidator : Validator Model
finishValidator =
    let
        before a b =
            Time.posixToMillis a > Time.posixToMillis b

        finishBeforeStart model =
            Maybe.map2 before
                (model.start |> DateTime.toPosix |> Result.toMaybe)
                (model.finish |> DateTime.toPosix |> Result.toMaybe)
                |> Maybe.withDefault False
    in
    Validator.all
        [ Validator.map .finish DateTime.validIfGivenValidator
        , Validator.fromPredicate "Can't finish a game before it is started." finishBeforeStart
        ]


validator : Validator Model
validator =
    Validator.all
        [ nameValidator
        , coverValidator
        , startValidator
        , finishValidator
        ]


view : msg -> (Msg -> msg) -> Parent a -> Model -> List (Html msg)
view save wrap parent model =
    let
        body () =
            let
                ( id, game ) =
                    toGame model

                preview =
                    [ Game.view parent.zone parent.time parent.auth.localUser id game ]

                textField name type_ value action attrs =
                    TextField.viewWithAttrs name type_ value action (HtmlA.attribute "outlined" "" :: attrs)
            in
            [ Html.div [ HtmlA.class "core-content" ]
                [ Html.div [ HtmlA.class "editor" ]
                    [ textField "Id" TextField.Text (id |> Game.idToString) Nothing []
                    , textField "Name" TextField.Text model.name (ChangeName >> wrap |> Just) [ HtmlA.required True ]
                    , Validator.view nameValidator model
                    , textField "Cover" TextField.Url model.cover (ChangeCover >> wrap |> Just) [ HtmlA.required True ]
                    , Validator.view coverValidator model
                    , DateTime.viewEditor "Start" model.start (ChangeStart >> wrap |> Just) [ HtmlA.attribute "outlined" "" ]
                    , Validator.view startValidator model
                    , DateTime.viewEditor "Finish" model.finish (ChangeFinish >> wrap |> Just) [ HtmlA.attribute "outlined" "" ]
                    , Validator.view finishValidator model
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
                    (save |> Validator.whenValid validator model)
                ]
            ]
    in
    model.source
        |> Maybe.map Tuple.second
        |> Maybe.map (RemoteData.map (always ()))
        |> Maybe.withDefault (RemoteData.Loaded ())
        |> RemoteData.view body
