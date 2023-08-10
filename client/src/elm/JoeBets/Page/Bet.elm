module JoeBets.Page.Bet exposing
    ( init
    , load
    , update
    , view
    )

import Browser.Navigation as Browser
import Html
import Html.Attributes as HtmlA
import JoeBets.Api as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.IdData as Api
import JoeBets.Api.Path as Api
import JoeBets.Bet as Bet
import JoeBets.Bet.Model as Bet
import JoeBets.Bet.PlaceBet as PlaceBet
import JoeBets.Bet.PlaceBet.Model as PlaceBet
import JoeBets.Feed as Feed
import JoeBets.Game as Game
import JoeBets.Game.Id as Game
import JoeBets.Messages as Global
import JoeBets.Page exposing (Page)
import JoeBets.Page.Bet.Model exposing (..)
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Page.User.Model as User
import JoeBets.Settings.Model as Settings
import JoeBets.User.Auth as User
import JoeBets.User.Auth.Model as Auth
import Time.Model as Time


wrap : Msg -> Global.Msg
wrap =
    Global.BetMsg


wrapBets : Bets.Msg -> Global.Msg
wrapBets =
    Global.BetsMsg


type alias Parent a =
    { a
        | bet : Model
        , bets : Bets.Model
        , settings : Settings.Model
        , origin : String
        , auth : Auth.Model
        , time : Time.Context
        , navigationKey : Browser.Key
    }


init : Model
init =
    { data = Api.initIdData
    , feed = Feed.init
    , placeBet = PlaceBet.init
    }


load : Game.Id -> Bet.Id -> Parent a -> ( Parent a, Cmd Global.Msg )
load gameId betId ({ bet, origin } as model) =
    let
        ( newData, loadCmd ) =
            { path = Api.Game gameId (Api.Bet betId Api.BetRoot)
            , wrap = Load ( gameId, betId ) >> wrap
            , decoder = gameAndBetDecoder
            }
                |> Api.get origin
                |> Api.getIdData ( gameId, betId ) bet.data

        ( newFeed, feedCmd ) =
            Feed.load (FeedMsg >> wrap)
                (Just ( gameId, betId ))
                model
                bet.feed
    in
    ( { model | bet = { bet | data = newData, feed = newFeed } }
    , Cmd.batch [ loadCmd, feedCmd ]
    )


updateBet : (Model -> Model) -> Parent a -> Parent a
updateBet f ({ bet } as model) =
    { model | bet = f bet }


update : Msg -> Parent a -> ( Parent a, Cmd Global.Msg )
update msg ({ origin, time } as model) =
    case msg of
        Load gameAndBetId gameAndBet ->
            let
                loadData bet =
                    { bet
                        | placeBet = Nothing
                        , data = bet.data |> Api.updateIdData gameAndBetId gameAndBet
                    }
            in
            ( model |> updateBet loadData, Cmd.none )

        Update gameAndBetId updated ->
            let
                updateGAndB gameAndBet =
                    { gameAndBet | bet = updated }

                updateInBet bet =
                    { bet
                        | placeBet = Nothing
                        , data = bet.data |> Api.updateIdDataValue gameAndBetId updateGAndB
                    }
            in
            ( model |> updateBet updateInBet, Cmd.none )

        Apply changes ->
            let
                closePlaceBet bet =
                    { bet | placeBet = Nothing }

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

                                updateInBet bet =
                                    { bet
                                        | placeBet = Nothing
                                        , data = bet.data |> Api.updateIdDataValue ( gameId, betId ) updateGAndB
                                    }
                            in
                            model |> updateBet updateInBet
            in
            ( List.foldl apply (model |> updateBet closePlaceBet) changes
            , Cmd.none
            )

        PlaceBetMsg placeBetMsg ->
            let
                ( newBet, cmd ) =
                    PlaceBet.update (PlaceBetMsg >> wrap)
                        (Apply >> wrap)
                        origin
                        time
                        placeBetMsg
                        model.bet
            in
            ( { model | bet = newBet }, cmd )

        FeedMsg feedMsg ->
            let
                bet =
                    model.bet

                ( feed, cmd ) =
                    Feed.update feedMsg bet.feed
            in
            ( { model | bet = { bet | feed = feed } }, cmd )


view : Parent a -> Page Global.Msg
view model =
    let
        placeBetView localUser =
            PlaceBet.view (PlaceBetMsg >> wrap) localUser model.bet.placeBet

        title =
            case model.bet.data |> Api.idDataToMaybe |> Maybe.map Tuple.second of
                Just { game, bet } ->
                    [ "“", bet.name, "”", " bet for ", "“", game.name, "”" ] |> String.concat

                Nothing ->
                    ""

        feedBody feed =
            [ feed
                |> Feed.view (FeedMsg >> wrap) True model
                |> Html.div [ HtmlA.class "feed" ]
            ]

        body ( gameId, betId ) { game, bet } =
            [ [ Html.div [ HtmlA.class "game-detail" ]
                    [ Game.view
                        Global.ChangeUrl
                        wrapBets
                        model.bets
                        model.time
                        model.auth.localUser
                        gameId
                        game
                    ]
              , Bet.view
                    Global.ChangeUrl
                    model.time
                    (Bet.readWriteFromAuth (PlaceBetMsg >> wrap) model.auth)
                    gameId
                    game.name
                    betId
                    bet
              ]
            , model.auth.localUser
                |> Maybe.map placeBetView
                |> Maybe.withDefault []
            ]
                |> List.concat
    in
    { title = title
    , id = "bet"
    , body =
        [ model.bet.data |> Api.viewIdData Api.viewOrError body
        , model.bet.feed |> feedBody
        ]
            |> List.concat
    }
