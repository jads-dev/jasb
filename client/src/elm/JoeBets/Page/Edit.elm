module JoeBets.Page.Edit exposing
    ( init
    , load
    , update
    , view
    )

import Browser.Navigation as Navigation
import Html
import Http
import JoeBets.Api as Api
import JoeBets.Bet.Editor as BetEditor
import JoeBets.Bet.Editor.Model as BetEditor
import JoeBets.Game.Editor as GameEditor
import JoeBets.Game.Editor.Model as GameEditor
import JoeBets.Page exposing (Page)
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Page.Edit.Model exposing (..)
import JoeBets.Page.Edit.Msg exposing (Msg(..))
import JoeBets.Page.Model as PageModel
import JoeBets.Page.Problem.Model as Problem
import JoeBets.Route as Route
import JoeBets.User.Auth.Model as Auth
import Time.Model as Time


type alias Parent a =
    { a
        | edit : Model
        , time : Time.Context
        , origin : String
        , auth : Auth.Model
        , navigationKey : Navigation.Key
        , problem : Problem.Model
        , page : PageModel.Page
        , bets : Bets.Model
    }


init : Model
init =
    Nothing


load : (Msg -> msg) -> Target -> Parent a -> ( Parent a, Cmd msg )
load wrap target model =
    case target of
        Game id ->
            let
                ( gameEditor, gameEditorCmd ) =
                    GameEditor.load model.origin (GameEditMsg >> wrap) id
            in
            ( { model | edit = gameEditor |> GameEditor |> Just }, gameEditorCmd )

        Bet gameId mode ->
            case model.auth.localUser of
                Just localUser ->
                    let
                        ( betEditor, betEditorCmd ) =
                            BetEditor.load model.origin
                                localUser
                                (BetEditMsg >> wrap)
                                gameId
                                mode
                    in
                    ( { model | edit = betEditor |> BetEditor |> Just }, betEditorCmd )

                Nothing ->
                    ( { model
                        | problem = Problem.MustBeLoggedIn { path = Route.Edit target |> Route.toUrl }
                        , page = PageModel.Problem
                      }
                    , Cmd.none
                    )


update : (Msg -> msg) -> Msg -> Parent a -> ( Parent a, Cmd msg )
update wrap msg ({ edit, auth } as model) =
    case msg of
        GameEditMsg gameEditMsg ->
            case edit of
                Just (GameEditor gameEditor) ->
                    let
                        ( newEditor, cmd ) =
                            GameEditor.update (GameEditMsg >> wrap) gameEditMsg model gameEditor
                    in
                    ( { model | edit = newEditor |> GameEditor |> Just }, cmd )

                _ ->
                    ( model, Cmd.none )

        BetEditMsg betEditMsg ->
            case edit of
                Just (BetEditor betEditor) ->
                    case auth.localUser of
                        Just user ->
                            let
                                ( newModel, cmd ) =
                                    BetEditor.update (BetEditMsg >> wrap) user betEditMsg model betEditor
                            in
                            ( { model | edit = newModel |> BetEditor |> Just }, cmd )

                        Nothing ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        Save ->
            case edit of
                Just editor ->
                    let
                        handle targetRoute result =
                            case result of
                                Ok _ ->
                                    Saved targetRoute

                                Err _ ->
                                    NoOp

                        specificRequest =
                            case editor of
                                GameEditor gameEditor ->
                                    let
                                        newOrUpdate =
                                            if GameEditor.isNew gameEditor then
                                                "PUT"

                                            else
                                                "POST"

                                        ( id, _ ) =
                                            gameEditor |> GameEditor.toGame
                                    in
                                    Ok
                                        { method = newOrUpdate
                                        , gameId = id
                                        , path = Api.GameRoot
                                        , body = gameEditor |> GameEditor.diff |> GameEditor.encodeBody
                                        , route = Route.Bets Bets.Active id
                                        }

                                BetEditor betEditor ->
                                    let
                                        newOrUpdate =
                                            if BetEditor.isNew betEditor then
                                                "PUT"

                                            else
                                                "POST"

                                        id =
                                            betEditor |> BetEditor.resolveId

                                        diff =
                                            betEditor |> BetEditor.diff

                                        requestBody body =
                                            { method = newOrUpdate
                                            , gameId = betEditor.gameId
                                            , path = Api.Bet id Api.BetRoot
                                            , body = body |> BetEditor.encodeDiff
                                            , route = Route.Bet betEditor.gameId id
                                            }
                                    in
                                    diff |> Result.map requestBody

                        sendRequest { method, gameId, path, body, route } =
                            ( model
                            , Api.request model.origin
                                method
                                { path = Api.Game gameId path
                                , body = body |> Http.jsonBody
                                , expect = (route |> handle) >> wrap |> Http.expectWhatever
                                }
                            )
                    in
                    specificRequest |> Result.map sendRequest |> Result.toMaybe |> Maybe.withDefault ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        Saved route ->
            ( model, Route.pushUrl model.navigationKey route )

        NoOp ->
            ( model, Cmd.none )


view : (Msg -> msg) -> (Bets.Msg -> msg) -> Parent a -> Page msg
view wrap wrapBets ({ edit, auth, time } as model) =
    let
        editor =
            case ( edit, auth.localUser ) of
                ( Just e, Just user ) ->
                    case e of
                        GameEditor gameEditor ->
                            GameEditor.view (wrap Save) (GameEditMsg >> wrap) wrapBets model gameEditor

                        BetEditor betEditor ->
                            BetEditor.view (wrap Save) (BetEditMsg >> wrap) time user betEditor

                _ ->
                    [ Html.p [] [ Html.text "You must be logged in to edit." ] ]
    in
    { title = "Edit"
    , id = "edit"
    , body = editor
    }
