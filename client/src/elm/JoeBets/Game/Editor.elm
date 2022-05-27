module JoeBets.Game.Editor exposing
    ( diff
    , isNew
    , load
    , toGame
    , update
    , view
    )

import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Http
import JoeBets.Api as Api
import JoeBets.Editing.Slug as Slug
import JoeBets.Editing.Uploader as Uploader
import JoeBets.Game as Game
import JoeBets.Game.Editor.Model exposing (..)
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game exposing (Game)
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Page.Edit.Validator as Validator exposing (Validator)
import JoeBets.User.Auth.Model as Auth
import Material.Button as Button
import Material.TextField as TextField
import Time
import Time.Date as Date
import Time.Model as Time
import Util.Maybe as Maybe
import Util.RemoteData as RemoteData
import Util.Url as Url


type alias Parent a =
    { a
        | time : Time.Context
        , origin : String
        , auth : Auth.Model
        , bets : Bets.Model
    }


empty : Maybe Game.Id -> Model
empty maybeGameId =
    { source = maybeGameId |> Maybe.map (\id -> ( id, RemoteData.Missing ))
    , id = Slug.Auto
    , name = ""
    , cover = Uploader.init
    , igdbId = ""
    , bets = 0
    , start = ""
    , finish = ""
    , order = Nothing
    }


diff : Model -> Body
diff model =
    let
        ifDifferent getOld getNew =
            Maybe.ifDifferent
                (model.source |> Maybe.andThen (Tuple.second >> RemoteData.toMaybe) |> Maybe.map getOld)
                (model |> getNew |> Just)
                |> Maybe.andThen identity
    in
    Body
        (model.source |> Maybe.andThen (Tuple.second >> RemoteData.toMaybe) |> Maybe.map .version)
        (ifDifferent .name .name)
        (ifDifferent .cover (.cover >> Uploader.toUrl))
        (ifDifferent .igdbId .igdbId)
        (ifDifferent (.progress >> Game.start) (.start >> Date.fromIso))
        (ifDifferent (.progress >> Game.finish) (.finish >> Date.fromIso))
        (ifDifferent .order .order)


load : String -> (Msg -> msg) -> Maybe Game.Id -> ( Model, Cmd msg )
load origin wrap maybeGameId =
    let
        model =
            empty maybeGameId

        cmd =
            case maybeGameId of
                Just id ->
                    Api.get origin
                        { path = Api.Game id Api.GameRoot
                        , expect = Http.expectJson (Load id >> wrap) Game.decoder
                        }

                Nothing ->
                    Cmd.none
    in
    ( model, cmd )


isNew : Model -> Bool
isNew { source } =
    source == Nothing


fromGame : Game.Id -> Game -> Model
fromGame id game =
    let
        ( startDate, finishDate ) =
            case game.progress of
                Game.Future _ ->
                    ( Nothing, Nothing )

                Game.Current { start } ->
                    ( Just start, Nothing )

                Game.Finished { start, finish } ->
                    ( Just start, Just finish )
    in
    { source = Just ( id, RemoteData.Loaded game )
    , id = Slug.Locked id
    , name = game.name
    , cover = game.cover |> Uploader.fromUrl
    , igdbId = game.igdbId
    , bets = game.bets
    , start = startDate |> Maybe.map Date.toIso |> Maybe.withDefault ""
    , finish = finishDate |> Maybe.map Date.toIso |> Maybe.withDefault ""
    , order = game.order
    }


update : (Msg -> msg) -> Msg -> Parent a -> Model -> ( Model, Cmd msg )
update wrap msg parent model =
    case msg of
        Load id result ->
            case result of
                Ok game ->
                    ( fromGame id game, Cmd.none )

                Err error ->
                    ( { model | source = Just ( id, RemoteData.Failed error ) }, Cmd.none )

        Reset ->
            case model.source of
                Just ( gameId, data ) ->
                    case data of
                        RemoteData.Loaded game ->
                            ( fromGame gameId game, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                Nothing ->
                    ( empty Nothing, Cmd.none )

        IgdbLoad _ ->
            ( model, Cmd.none )

        IgdbSet name cover ->
            ( { model | name = name, cover = model.cover |> Uploader.setUrl cover }, Cmd.none )

        ChangeId id ->
            ( { model | id = id |> Url.slugify |> Game.idFromString |> Slug.Manual }, Cmd.none )

        ChangeName name ->
            ( { model | name = name }, Cmd.none )

        CoverMsg coverMsg ->
            let
                ( cover, cmd ) =
                    Uploader.update (CoverMsg >> wrap) coverMsg parent coverUploaderModel model.cover
            in
            ( { model | cover = cover }, cmd )

        ChangeIgdbId igdbId ->
            ( { model | igdbId = igdbId }, Cmd.none )

        ChangeStart start ->
            ( { model | start = start }, Cmd.none )

        ChangeFinish finish ->
            ( { model | finish = finish }, Cmd.none )

        ChangeOrder stringOrder ->
            let
                order =
                    if String.isEmpty stringOrder then
                        Nothing

                    else
                        String.toInt stringOrder
            in
            ( { model | order = order }, Cmd.none )


toGame : Model -> ( Game.Id, Game )
toGame model =
    let
        progress =
            case model.start |> Date.fromIso of
                Just start ->
                    case model.finish |> Date.fromIso of
                        Just finish ->
                            { start = start, finish = finish } |> Game.Finished

                        Nothing ->
                            { start = start } |> Game.Current

                Nothing ->
                    {} |> Game.Future

        version =
            model.source
                |> Maybe.andThen (Tuple.second >> RemoteData.toMaybe)
                |> Maybe.map (.version >> (+) 1)
                |> Maybe.withDefault 0

        coverUrl =
            model.cover |> Uploader.toUrl
    in
    ( model.source
        |> Maybe.map Tuple.first
        |> Maybe.withDefault (model.name |> Url.slugify |> Game.idFromString)
    , Game version model.name coverUrl model.igdbId model.bets progress model.order
    )


nameValidator : Validator Model
nameValidator =
    Validator.fromPredicate "Name must not be empty." (.name >> String.isEmpty)


coverValidator : Validator Model
coverValidator =
    Validator.fromPredicate "Cover must not be empty." (.cover >> Uploader.toUrl >> String.isEmpty)


dateValidator : String -> Validator String
dateValidator name value =
    if value |> String.isEmpty then
        []

    else
        case value |> Date.fromIso of
            Just _ ->
                []

            Nothing ->
                [ name ++ " must be a valid date." ]


dateNotEmptyValidator : Validator String
dateNotEmptyValidator value =
    if value |> String.isEmpty then
        [ "Must not be empty." ]

    else
        []


startValidator : Validator Model
startValidator model =
    let
        startGiven =
            Validator.map .start dateNotEmptyValidator

        finishGiven =
            Validator.map .finish dateNotEmptyValidator
    in
    if Validator.valid finishGiven model && (Validator.valid startGiven model |> not) then
        [ "A start must be given if a finish is." ]

    else
        Validator.map .start (dateValidator "Start") model


finishValidator : Validator Model
finishValidator =
    let
        before a b =
            Time.posixToMillis a > Time.posixToMillis b

        finishBeforeStart model =
            Maybe.map2 before
                (model.start |> Date.fromIso |> Maybe.map Date.toPosix)
                (model.finish |> Date.fromIso |> Maybe.map Date.toPosix)
                |> Maybe.withDefault False
    in
    Validator.all
        [ Validator.map .finish (dateValidator "Finish")
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


view : msg -> (Msg -> msg) -> (Bets.Msg -> msg) -> Parent a -> Model -> List (Html msg)
view save wrap wrapBets parent model =
    let
        body () =
            let
                ( id, game ) =
                    toGame model

                preview =
                    [ Game.view wrapBets parent.bets parent.time parent.auth.localUser id game Nothing ]

                textField name type_ value action attrs =
                    TextField.viewWithAttrs name type_ value action (HtmlA.attribute "outlined" "" :: attrs)
            in
            [ Html.div [ HtmlA.class "core-content" ]
                [ Html.div [ HtmlA.class "editor" ]
                    [ Slug.view Game.idFromString Game.idToString (ChangeId >> wrap) model.name model.id
                    , textField "Name" TextField.Text model.name (ChangeName >> wrap |> Just) [ HtmlA.required True ]
                    , Validator.view nameValidator model
                    , Uploader.view (CoverMsg >> wrap) coverUploaderModel model.cover
                    , Validator.view coverValidator model
                    , textField "IGDB Id" TextField.Text model.igdbId (ChangeIgdbId >> wrap |> Just) [ HtmlA.required True ]
                    , Date.viewEditor "Start"
                        model.start
                        (ChangeStart >> wrap |> Just)
                        [ HtmlA.attribute "outlined" "" ]
                    , Validator.view startValidator model
                    , Date.viewEditor "Finish"
                        model.finish
                        (ChangeFinish >> wrap |> Just)
                        [ HtmlA.attribute "outlined" "" ]
                    , Validator.view finishValidator model
                    , textField "Order"
                        TextField.Number
                        (model.order |> Maybe.map String.fromInt |> Maybe.withDefault "")
                        (ChangeOrder >> wrap |> Just)
                        []
                    ]
                , Html.div [ HtmlA.class "preview" ] preview
                ]
            , Html.div [ HtmlA.class "controls" ]
                [ Button.view Button.Standard
                    Button.Padded
                    "Reset"
                    (Icon.undo |> Icon.view |> Just)
                    (Reset |> wrap |> Just)
                , Button.view Button.Raised
                    Button.Padded
                    "Save"
                    (Icon.save |> Icon.view |> Just)
                    (save |> Validator.whenValid validator model)
                ]
            ]
    in
    model.source
        |> Maybe.map Tuple.second
        |> Maybe.map (RemoteData.map (always ()))
        |> Maybe.withDefault (RemoteData.Loaded ())
        |> RemoteData.view body


coverUploaderModel : Uploader.Model
coverUploaderModel =
    { label = "Cover"
    , types = [ "image/*" ]
    }
