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
import JoeBets.Bet.Model as Bet
import JoeBets.Game.Editor as GameEditor
import JoeBets.Game.Model as Game
import JoeBets.Page exposing (Page)
import JoeBets.Page.Edit.Model exposing (..)
import JoeBets.Page.Edit.Msg exposing (Msg(..))
import JoeBets.Route as Route
import JoeBets.User.Auth.Model as Auth
import Time


type alias Parent a =
    { a
        | edit : Model
        , zone : Time.Zone
        , time : Time.Posix
        , origin : String
        , auth : Auth.Model
        , navigationKey : Navigation.Key
    }


init : Model
init =
    Nothing


load : (Msg -> msg) -> Target -> Parent a -> ( Parent a, Cmd msg )
load wrap target model =
    let
        ( edit, cmd ) =
            case target of
                Game id ->
                    let
                        ( gameEditor, gameEditorCmd ) =
                            GameEditor.load model.origin (GameEditMsg >> wrap) id
                    in
                    ( GameEditor gameEditor, gameEditorCmd )

                Bet gameId betId ->
                    let
                        ( betEditor, betEditorCmd ) =
                            BetEditor.load model.origin (BetEditMsg >> wrap) gameId betId
                    in
                    ( BetEditor betEditor, betEditorCmd )
    in
    ( { model | edit = Just edit }, cmd )


update : (Msg -> msg) -> Msg -> Parent a -> ( Parent a, Cmd msg )
update wrap msg ({ edit, auth } as model) =
    case msg of
        GameEditMsg gameEditMsg ->
            case edit of
                Just (GameEditor gameEditor) ->
                    ( { model | edit = GameEditor.update gameEditMsg gameEditor |> GameEditor |> Just }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        BetEditMsg betEditMsg ->
            case edit of
                Just (BetEditor betEditor) ->
                    ( { model | edit = BetEditor.update betEditMsg betEditor |> BetEditor |> Just }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        Save ->
            case ( edit, auth.localUser |> Maybe.map .id ) of
                ( Just editor, Just userId ) ->
                    let
                        handle targetRoute result =
                            case result of
                                Ok _ ->
                                    Saved targetRoute

                                Err _ ->
                                    NoOp

                        { gameId, path, body, route } =
                            case editor of
                                GameEditor gameEditor ->
                                    let
                                        ( id, game ) =
                                            gameEditor |> GameEditor.toGame
                                    in
                                    { gameId = id
                                    , path = []
                                    , body = game |> Game.encode
                                    , route = Route.Bets id Nothing
                                    }

                                BetEditor betEditor ->
                                    let
                                        ( id, bet ) =
                                            betEditor |> BetEditor.toBet userId
                                    in
                                    { gameId = betEditor.gameId
                                    , path = [ id |> Bet.idToString ]
                                    , body = Bet.encode bet
                                    , route = Route.Bet betEditor.gameId id
                                    }
                    in
                    ( model
                    , Api.put model.origin
                        { path = [ "game", gameId |> Game.idToString ] ++ path
                        , body = body |> Http.jsonBody
                        , expect = (route |> handle) >> wrap |> Http.expectWhatever
                        }
                    )

                _ ->
                    ( model, Cmd.none )

        Saved route ->
            ( model, Route.pushUrl model.navigationKey route )

        NoOp ->
            ( model, Cmd.none )


view : (Msg -> msg) -> Parent a -> Page msg
view wrap ({ edit, auth } as model) =
    let
        editor =
            case ( edit, auth.localUser ) of
                ( Just e, Just user ) ->
                    case e of
                        GameEditor gameEditor ->
                            GameEditor.view (wrap Save) (GameEditMsg >> wrap) model gameEditor

                        BetEditor betEditor ->
                            BetEditor.view (wrap Save) (BetEditMsg >> wrap) user betEditor

                _ ->
                    [ Html.p [] [ Html.text "You must be logged in to edit." ] ]
    in
    { title = "Edit"
    , id = "edit"
    , body = editor
    }
