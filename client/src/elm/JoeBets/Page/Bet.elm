module JoeBets.Page.Bet exposing
    ( init
    , load
    , update
    , view
    )

import Browser.Navigation as Navigation
import Http
import JoeBets.Api as Api
import JoeBets.Bet as Bet
import JoeBets.Bet.Model as Bet
import JoeBets.Bet.PlaceBet as PlaceBet
import JoeBets.Game as Game
import JoeBets.Game.Model as Game
import JoeBets.Page exposing (Page)
import JoeBets.Page.Bet.Model exposing (..)
import JoeBets.User.Auth.Model as Auth
import Time
import Util.RemoteData as RemoteData


type alias Parent a =
    { a
        | bet : Model
        , origin : String
        , auth : Auth.Model
        , zone : Time.Zone
        , time : Time.Posix
        , navigationKey : Navigation.Key
    }


init : Model
init =
    { data = Nothing
    , placeBet = PlaceBet.init
    }


load : (Msg -> msg) -> Game.Id -> Bet.Id -> Parent a -> ( Parent a, Cmd msg )
load wrap gameId betId ({ bet } as model) =
    let
        existing =
            bet.data |> Maybe.map (\d -> ( d.gameId, d.betId ))

        newBet =
            if Just ( gameId, betId ) /= existing then
                { bet | data = Data gameId betId RemoteData.Missing |> Just }

            else
                bet
    in
    ( { model | bet = newBet }
    , Api.get model.origin
        { path = [ "game", gameId |> Game.idToString, betId |> Bet.idToString ]
        , expect = Http.expectJson (Load gameId betId >> wrap) gameAndBetDecoder
        }
    )


update : (Msg -> msg) -> Msg -> Parent a -> ( Parent a, Cmd msg )
update wrap msg model =
    case msg of
        Load gameId betId gameAndBet ->
            let
                oldBet =
                    model.bet

                updateData data =
                    if data.gameId == gameId && data.betId == betId then
                        { data | gameAndBet = RemoteData.load gameAndBet }

                    else
                        data
            in
            ( { model | bet = { oldBet | data = oldBet.data |> Maybe.map updateData } }, Cmd.none )

        Update gameId betId bet ->
            let
                oldBet =
                    model.bet

                updateData data =
                    if data.gameId == gameId && data.betId == betId then
                        { data | gameAndBet = data.gameAndBet |> RemoteData.map (\gB -> { gB | bet = bet }) }

                    else
                        data
            in
            ( { model | bet = { oldBet | data = oldBet.data |> Maybe.map updateData } }, Cmd.none )

        PlaceBetMsg placeBetMsg ->
            let
                ( newBet, cmd ) =
                    PlaceBet.update (PlaceBetMsg >> wrap)
                        (\gid bid b _ -> Update gid bid b |> wrap)
                        model.origin
                        placeBetMsg
                        model.bet
            in
            ( { model | bet = newBet }, cmd )


view : (Msg -> msg) -> Parent a -> Page msg
view wrap model =
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

        body { gameId, betId, game, bet } =
            [ [ Game.view model.zone model.time model.auth.localUser gameId game
              , Bet.view (Bet.voteAsFromAuth (PlaceBetMsg >> wrap) model.auth) gameId game.name betId bet
              ]
            , model.auth.localUser |> Maybe.map placeBetView |> Maybe.withDefault []
            ]
                |> List.concat
    in
    { title = title
    , id = "bet"
    , body = remoteData |> RemoteData.view body
    }
