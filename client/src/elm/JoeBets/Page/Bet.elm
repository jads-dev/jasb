module JoeBets.Page.Bet exposing
    ( init
    , load
    , update
    , view
    )

import Browser.Navigation as Navigation
import Html
import Html.Attributes as HtmlA
import Http
import JoeBets.Api as Api
import JoeBets.Bet as Bet
import JoeBets.Bet.Model as Bet
import JoeBets.Bet.PlaceBet as PlaceBet
import JoeBets.Bet.PlaceBet.Model as PlaceBet
import JoeBets.Game as Game
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game
import JoeBets.Page exposing (Page)
import JoeBets.Page.Bet.Model exposing (..)
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Page.Feed as Feed
import JoeBets.Page.User.Model as User
import JoeBets.Settings.Model as Settings
import JoeBets.User.Auth as User
import JoeBets.User.Auth.Model as Auth
import Time.Model as Time
import Util.RemoteData as RemoteData


type alias Parent a =
    { a
        | bet : Model
        , bets : Bets.Model
        , settings : Settings.Model
        , origin : String
        , auth : Auth.Model
        , time : Time.Context
        , navigationKey : Navigation.Key
    }


init : Model
init =
    { data = Nothing
    , feed = Feed.init
    , placeBet = PlaceBet.init
    }


load : (Msg -> msg) -> Game.Id -> Bet.Id -> Parent a -> ( Parent a, Cmd msg )
load wrap gameId betId ({ bet, bets, settings, origin } as model) =
    let
        existing =
            bet.data |> Maybe.map (\d -> ( d.gameId, d.betId ))

        newBet =
            if Just ( gameId, betId ) /= existing then
                { bet | data = Data gameId betId RemoteData.Missing |> Just, feed = Feed.init }

            else
                bet

        ( feedModel, feedCmd ) =
            Feed.load (FeedMsg >> wrap)
                (Just ( gameId, betId ))
                { feed = bet.feed, bets = bets, settings = settings, origin = origin }
    in
    ( { model | bet = { newBet | feed = feedModel.feed } }
    , Cmd.batch
        [ Api.get model.origin
            { path = Api.Game gameId (Api.Bet betId Api.BetRoot)
            , expect = Http.expectJson (Load gameId betId >> wrap) gameAndBetDecoder
            }
        , feedCmd
        ]
    )


update : (Msg -> msg) -> Msg -> Parent a -> ( Parent a, Cmd msg )
update wrap msg ({ bet, settings, origin, bets, time } as model) =
    let
        updateRemoteData gameId betId change m =
            let
                updateIfMatching data =
                    if data.gameId == gameId && data.betId == betId then
                        { data | gameAndBet = data.gameAndBet |> change }

                    else
                        data
            in
            { m | bet = { bet | data = bet.data |> Maybe.map updateIfMatching } }
    in
    case msg of
        Load gameId betId gameAndBet ->
            ( model |> updateRemoteData gameId betId (gameAndBet |> RemoteData.load >> always), Cmd.none )

        Update gameId betId updated ->
            let
                updateGAndB gameAndBet =
                    { gameAndBet | bet = updated }

                newModel =
                    { model | bet = { bet | placeBet = Nothing } }
                        |> updateRemoteData gameId betId (RemoteData.map updateGAndB)
            in
            ( newModel, Cmd.none )

        Apply changes ->
            let
                apply change m =
                    case change of
                        PlaceBet.User userId userChange ->
                            let
                                updateUser id =
                                    if id == userId then
                                        User.apply userChange

                                    else
                                        identity
                            in
                            m |> User.updateLocalUser updateUser

                        PlaceBet.Bet gameId betId betChange ->
                            let
                                updateGAndB gAndB =
                                    { gAndB | bet = gAndB.bet |> Bet.apply betChange }
                            in
                            m |> updateRemoteData gameId betId (RemoteData.map updateGAndB)
            in
            ( List.foldl apply { model | bet = { bet | placeBet = Nothing } } changes, Cmd.none )

        PlaceBetMsg placeBetMsg ->
            let
                ( newBet, cmd ) =
                    PlaceBet.update (PlaceBetMsg >> wrap)
                        (Apply >> wrap)
                        origin
                        time
                        placeBetMsg
                        bet
            in
            ( { model | bet = newBet }, cmd )

        FeedMsg feedMsg ->
            let
                ( { feed }, cmd ) =
                    Feed.update (FeedMsg >> wrap)
                        feedMsg
                        { feed = bet.feed, bets = bets, settings = settings, origin = origin }
            in
            ( { model | bet = { bet | feed = feed } }, cmd )


view : (Msg -> msg) -> (Bets.Msg -> msg) -> Parent a -> Page msg
view wrap wrapBets model =
    let
        remoteData =
            case model.bet.data of
                Just { gameId, betId, gameAndBet } ->
                    gameAndBet
                        |> RemoteData.map (\{ game, bet } -> { gameId = gameId, betId = betId, game = game, bet = bet })

                Nothing ->
                    RemoteData.Missing

        placeBetView localUser =
            PlaceBet.view (PlaceBetMsg >> wrap) localUser model.bet.placeBet

        title =
            case model.bet.data |> Maybe.andThen (.gameAndBet >> RemoteData.toMaybe) of
                Just { game, bet } ->
                    [ "“", bet.name, "”", " bet for ", "“", game.name, "”" ] |> String.concat

                Nothing ->
                    ""

        feedBody feed =
            let
                feedPage =
                    Feed.view (FeedMsg >> wrap)
                        True
                        { feed = feed, bets = model.bets, settings = model.settings, origin = model.origin }
            in
            [ Html.div [ HtmlA.class "feed" ] feedPage.body ]

        body { gameId, betId, game, bet } =
            [ [ Game.view wrapBets model.bets model.time model.auth.localUser gameId game Nothing
              , Bet.view model.time (Bet.voteAsFromAuth (PlaceBetMsg >> wrap) model.auth) gameId game.name betId bet
              ]
            , model.auth.localUser |> Maybe.map placeBetView |> Maybe.withDefault []
            ]
                |> List.concat
    in
    { title = title
    , id = "bet"
    , body = [ remoteData |> RemoteData.view body, model.bet.feed |> feedBody ] |> List.concat
    }
