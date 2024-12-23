module Jasb.Page.Edit exposing
    ( init
    , load
    , update
    , view
    )

import Browser.Navigation as Browser
import Html
import Jasb.Bet.Editor as BetEditor
import Jasb.Game.Editor as GameEditor
import Jasb.Messages as Global
import Jasb.Page exposing (Page)
import Jasb.Page.Bets.Model as Bets
import Jasb.Page.Edit.Model exposing (..)
import Jasb.Page.Edit.Msg exposing (Msg(..))
import Jasb.Page.Problem.Model as Problem
import Jasb.Route as Route exposing (Route)
import Jasb.User.Auth.Controls as Auth
import Jasb.User.Auth.Model as Auth
import Time.Model as Time


wrap : Msg -> Global.Msg
wrap =
    Global.EditMsg


type alias Parent a =
    { a
        | edit : Model
        , time : Time.Context
        , origin : String
        , auth : Auth.Model
        , navigationKey : Browser.Key
        , problem : Problem.Model
        , bets : Bets.Model
        , route : Route
    }


init : Model
init =
    Nothing


load : Target -> Parent a -> ( Parent a, Cmd Global.Msg )
load target model =
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
                    ( Auth.mustBeLoggedIn (Route.Edit target) model
                    , Cmd.none
                    )


update : Msg -> Parent a -> ( Parent a, Cmd Global.Msg )
update msg ({ edit } as model) =
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
                    let
                        ( newModel, cmd ) =
                            BetEditor.update (BetEditMsg >> wrap)
                                betEditMsg
                                model
                                betEditor
                    in
                    ( { model | edit = newModel |> BetEditor |> Just }, cmd )

                _ ->
                    ( model, Cmd.none )


view : Target -> Parent a -> Page Global.Msg
view _ ({ edit, auth, time } as model) =
    let
        editor =
            case ( edit, auth.localUser ) of
                ( Just e, Just user ) ->
                    case e of
                        GameEditor gameEditor ->
                            GameEditor.view Global.ChangeUrl (GameEditMsg >> wrap) Global.BetsMsg model gameEditor

                        BetEditor betEditor ->
                            BetEditor.view Global.ChangeUrl (BetEditMsg >> wrap) time user betEditor

                _ ->
                    [ Html.p [] [ Html.text "You must be logged in to edit." ] ]
    in
    { title = "Edit"
    , id = "edit"
    , body = editor
    }
