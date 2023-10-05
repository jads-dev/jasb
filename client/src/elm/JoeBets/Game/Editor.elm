module JoeBets.Game.Editor exposing
    ( diff
    , isNew
    , load
    , toGame
    , update
    , view
    )

import AssocList
import Browser.Navigation as Browser
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Api as Api
import JoeBets.Api.Action as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.Path as Api
import JoeBets.Editing.Slug as Slug
import JoeBets.Editing.Uploader as Uploader
import JoeBets.Editing.Validator as Validator exposing (Validator)
import JoeBets.Game as Game
import JoeBets.Game.Editor.Model exposing (..)
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game exposing (Game)
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Route as Route exposing (Route)
import JoeBets.User.Auth.Model as Auth
import Material.Button as Button
import Material.TextField as TextField
import Time
import Time.Date as Date
import Time.DateTime as DateTime
import Time.Model as Time
import Util.Maybe as Maybe
import Util.Url as Url


type alias Parent a =
    { a
        | time : Time.Context
        , origin : String
        , auth : Auth.Model
        , bets : Bets.Model
        , navigationKey : Browser.Key
    }


empty : Model
empty =
    { source = Nothing
    , id = Slug.Auto
    , name = ""
    , cover = Uploader.init
    , bets = 0
    , start = ""
    , finish = ""
    , order = Nothing
    , saving = Api.initAction
    }


fromId : String -> (Msg -> msg) -> Game.Id -> ( Model, Cmd msg )
fromId origin wrap gameId =
    let
        ( data, cmd ) =
            { path = Api.Game gameId Api.GameRoot
            , decoder = Game.decoder
            , wrap = Load gameId >> wrap
            }
                |> Api.get origin
                |> Api.initGetData
    in
    ( { source = Just ( gameId, data )
      , id = Slug.Auto
      , name = ""
      , cover = Uploader.init
      , bets = 0
      , start = ""
      , finish = ""
      , order = Nothing
      , saving = Api.initAction
      }
    , cmd
    )


diff : Model -> Body
diff model =
    let
        ifDifferent getOld getNew =
            Maybe.ifDifferent
                (model.source |> Maybe.andThen (Tuple.second >> Api.dataToMaybe) |> Maybe.map getOld)
                (model |> getNew |> Just)
                |> Maybe.andThen identity
    in
    Body
        (model.source |> Maybe.andThen (Tuple.second >> Api.dataToMaybe) |> Maybe.map .version)
        (ifDifferent .name .name)
        (ifDifferent .cover (.cover >> Uploader.toUrl))
        (ifDifferent (.progress >> Game.start) (.start >> Date.fromIso))
        (ifDifferent (.progress >> Game.finish) (.finish >> Date.fromIso))
        (ifDifferent .order .order)


load : String -> (Msg -> msg) -> Maybe Game.Id -> ( Model, Cmd msg )
load origin wrap =
    Maybe.map (fromId origin wrap) >> Maybe.withDefault ( empty, Cmd.none )


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
    { source = Just ( id, Api.initDataFromValue game )
    , id = Slug.Locked id
    , name = game.name
    , cover = game.cover |> Uploader.fromUrl
    , bets = game.bets
    , start = startDate |> Maybe.map Date.toIso |> Maybe.withDefault ""
    , finish = finishDate |> Maybe.map Date.toIso |> Maybe.withDefault ""
    , order = game.order
    , saving = Api.initAction
    }


update : (Msg -> msg) -> Msg -> Parent a -> Model -> ( Model, Cmd msg )
update wrap msg ({ origin, navigationKey } as parent) model =
    case msg of
        Load id result ->
            case result of
                Ok game ->
                    ( fromGame id game, Cmd.none )

                Err error ->
                    ( { model | source = Just ( id, Api.initDataFromError error ) }, Cmd.none )

        Reset ->
            case model.source of
                Just ( gameId, data ) ->
                    case data |> Api.dataToMaybe of
                        Just game ->
                            ( fromGame gameId game, Cmd.none )

                        Nothing ->
                            ( model, Cmd.none )

                Nothing ->
                    ( empty, Cmd.none )

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

        Save ->
            let
                method =
                    if isNew model then
                        Api.put

                    else
                        Api.post

                ( gameId, _ ) =
                    toGame model

                ( actionState, cmd ) =
                    { path = Api.GameRoot |> Api.Game gameId
                    , body = model |> diff |> encodeBody
                    , wrap = Saved gameId >> wrap
                    , decoder = Game.decoder
                    }
                        |> method origin
                        |> Api.doAction model.saving
            in
            ( { model | saving = actionState }, cmd )

        Saved gameId result ->
            let
                ( maybeGame, actionState ) =
                    model.saving |> Api.handleActionResult result

                redirect _ =
                    gameId
                        |> Route.Bets Bets.Active
                        |> Route.pushUrl navigationKey
            in
            ( { model | saving = actionState }
            , maybeGame |> Maybe.map redirect |> Maybe.withDefault Cmd.none
            )


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

        { version, created, modified, staked, managers } =
            case model.source |> Maybe.map Tuple.second |> Maybe.andThen Api.dataToMaybe of
                Just source ->
                    { version = source.version + 1
                    , created = source.created
                    , modified = source.modified
                    , staked = source.staked
                    , managers = source.managers
                    }

                Nothing ->
                    { version = 0
                    , created = 0 |> Time.millisToPosix |> DateTime.fromPosix
                    , modified = 0 |> Time.millisToPosix |> DateTime.fromPosix
                    , staked = 0
                    , managers = AssocList.empty
                    }

        coverUrl =
            model.cover |> Uploader.toUrl
    in
    ( model.source
        |> Maybe.map Tuple.first
        |> Maybe.withDefault (model.name |> Url.slugify |> Game.idFromString)
    , Game model.name coverUrl progress model.order model.bets staked managers version created modified
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


view : (Route -> msg) -> (Msg -> msg) -> (Bets.Msg -> msg) -> Parent a -> Model -> List (Html msg)
view changeUrl wrap wrapBets parent model =
    let
        ( id, game ) =
            toGame model

        source =
            model.source |> Maybe.map Tuple.second |> Maybe.andThen Api.dataToMaybe

        preview =
            [ Game.view changeUrl wrapBets parent.bets parent.time parent.auth.localUser id game ]

        ifNotSaving =
            Api.ifNotWorking model.saving
    in
    [ Html.div [ HtmlA.class "core-content" ]
        [ Html.div [ HtmlA.class "editor" ]
            [ Html.h3 [] [ Html.text "Metadata" ]
            , Html.div [ HtmlA.class "metadata" ]
                [ Html.div [ HtmlA.class "created" ]
                    [ Html.text "Created: "
                    , source |> Maybe.map (.created >> DateTime.view parent.time Time.Absolute) |> Maybe.withDefault (Html.text "- (New)")
                    ]
                , Html.div [ HtmlA.class "modified" ]
                    [ Html.text "Last Modified: "
                    , source |> Maybe.map (.modified >> DateTime.view parent.time Time.Absolute) |> Maybe.withDefault (Html.text "- (New)")
                    ]
                , Html.div [ HtmlA.class "version" ]
                    [ Html.text "Version: "
                    , source |> Maybe.map (.version >> String.fromInt) |> Maybe.withDefault "- (New)" |> Html.text
                    ]
                ]
            , Slug.view Game.idFromString Game.idToString (ChangeId >> wrap |> Just |> ifNotSaving) model.name model.id
            , TextField.outlined "Name" (ChangeName >> wrap |> Just |> ifNotSaving) model.name
                |> TextField.required True
                |> Validator.textFieldError nameValidator model
                |> TextField.view
            , Uploader.view (CoverMsg >> wrap |> Just |> ifNotSaving) coverUploaderModel model.cover
            , Validator.view coverValidator model
            , Date.viewEditor "Start"
                model.start
                (ChangeStart >> wrap |> Just |> ifNotSaving)
                []
            , Validator.view startValidator model
            , Date.viewEditor "Finish"
                model.finish
                (ChangeFinish >> wrap |> Just |> ifNotSaving)
                []
            , Validator.view finishValidator model
            , TextField.outlined "Order"
                (ChangeOrder >> wrap |> Just |> ifNotSaving)
                (model.order |> Maybe.map String.fromInt |> Maybe.withDefault "")
                |> TextField.view
            ]
        , Html.div [ HtmlA.class "preview" ] preview
        ]
    , model.source
        |> Maybe.map (Tuple.second >> Api.viewErrorIfFailed)
        |> Maybe.withDefault []
        |> Html.div []
    , Html.div [ HtmlA.class "controls" ]
        [ Button.text "Reset"
            |> Button.button (Reset |> wrap |> Just)
            |> Button.icon [ Icon.undo |> Icon.view ]
            |> Button.view
        , Button.text "Save"
            |> Button.button (Save |> wrap |> Validator.whenValid validator model |> ifNotSaving)
            |> Button.icon [ Icon.save |> Icon.view ]
            |> Button.view
        ]
    ]


coverUploaderModel : Uploader.Model
coverUploaderModel =
    { label = "Cover"
    , types = [ "image/*" ]
    }
