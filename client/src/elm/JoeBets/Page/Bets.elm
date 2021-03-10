module JoeBets.Page.Bets exposing
    ( init
    , load
    , update
    , view
    )

import AssocList
import Browser.Navigation as Navigation
import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Keyed as HtmlK
import Http
import JoeBets.Api as Api
import JoeBets.Bet as Bet
import JoeBets.Bet.Model as Bet
import JoeBets.Bet.PlaceBet as PlaceBet
import JoeBets.Game as Game
import JoeBets.Game.Model as Game
import JoeBets.Page exposing (Page)
import JoeBets.Page.Bets.Model exposing (..)
import JoeBets.Page.Edit.Model as Edit
import JoeBets.Route as Route
import JoeBets.User.Auth.Model as Auth
import Material.Switch as Switch
import Time
import Util.RemoteData as RemoteData exposing (RemoteData)


type alias Parent a =
    { a
        | bets : Model
        , origin : String
        , auth : Auth.Model
        , zone : Time.Zone
        , time : Time.Posix
        , navigationKey : Navigation.Key
    }


init : Model
init =
    { gameBets = Nothing
    , filters = initFilters
    , placeBet = PlaceBet.init
    }


defaultFilters : ResolvedFilters
defaultFilters =
    { spoilers = False
    , voting = True
    , locked = True
    , complete = True
    , cancelled = False
    , hasBet = True
    }


resolveDefaults : Filters -> ResolvedFilters
resolveDefaults =
    resolveFilters defaultFilters


load : (Msg -> msg) -> Game.Id -> Maybe Filters -> Parent a -> ( Parent a, Cmd msg )
load wrap id filters ({ bets } as model) =
    let
        ( newBets, cmd ) =
            if Just id /= (model.bets.gameBets |> Maybe.map Tuple.first) then
                let
                    existingFilters =
                        bets.filters
                in
                ( { bets
                    | gameBets = Just ( id, RemoteData.Missing )
                    , filters = { existingFilters | spoilers = Nothing }
                  }
                , Api.get model.origin
                    { path = [ "game", id |> Game.idToString ]
                    , expect = Http.expectJson (Load id >> wrap) gameBetsDecoder
                    }
                )

            else
                ( bets, Cmd.none )

        updateFiltersFromUrlIfGiven =
            case filters of
                Just fs ->
                    updateFiltersFromUrl fs

                Nothing ->
                    identity
    in
    ( { model | bets = newBets |> updateFiltersFromUrlIfGiven }, cmd )


update : (Msg -> msg) -> Msg -> Parent a -> ( Parent a, Cmd msg )
update wrap msg ({ bets } as model) =
    case msg of
        Load id result ->
            case model.bets.gameBets of
                Just ( existingId, _ ) ->
                    if existingId == id then
                        ( { model | bets = { bets | gameBets = Just ( existingId, RemoteData.load result ) } }, Cmd.none )

                    else
                        ( model, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        PlaceBetMsg placeBetMsg ->
            let
                ( newBets, cmd ) =
                    PlaceBet.update (PlaceBetMsg >> wrap)
                        (\gid bid b u -> Update gid bid b u |> wrap)
                        model.origin
                        placeBetMsg
                        model.bets
            in
            ( { model | bets = newBets }, cmd )

        Update gameId betId bet user ->
            let
                auth =
                    model.auth

                closed =
                    { bets | placeBet = Nothing }

                newBets =
                    case closed.gameBets of
                        Just ( closedId, RemoteData.Loaded data ) ->
                            if closedId == gameId then
                                let
                                    updated =
                                        data.bets |> AssocList.update betId (bet |> Just |> always)

                                    gameBets =
                                        RemoteData.Loaded { data | bets = updated }
                                in
                                { closed | gameBets = Just ( closedId, gameBets ) }

                            else
                                closed

                        _ ->
                            closed

                replaceUser withId =
                    { withId | user = user }
            in
            ( { model
                | bets = newBets
                , auth = { auth | localUser = auth.localUser |> Maybe.map replaceUser }
              }
            , Cmd.none
            )

        SetFilter filter visible ->
            case model.bets.gameBets of
                Just ( id, _ ) ->
                    let
                        newBets =
                            bets |> updateFilters filter visible
                    in
                    ( model, Route.replaceUrl model.navigationKey (Route.Bets id (Just newBets.filters)) )

                Nothing ->
                    ( model, Cmd.none )


view : (Msg -> msg) -> Parent a -> Page msg
view wrap model =
    let
        body ( id, { game, bets } ) =
            let
                filters =
                    model.bets.filters |> resolveDefaults

                viewBet ( betId, bet ) =
                    Bet.viewFiltered (Bet.voteAsFromAuth (PlaceBetMsg >> wrap) model.auth)
                        filters
                        id
                        game.name
                        betId
                        bet
                        |> Maybe.map (List.singleton >> Html.li [] >> Tuple.pair (betId |> Bet.idToString))

                shownBets =
                    bets |> AssocList.toList |> List.filterMap viewBet

                shownAmount =
                    [ shownBets |> List.length |> String.fromInt |> Html.text
                    , Html.text "/"
                    , bets |> AssocList.size |> String.fromInt |> Html.text
                    , Html.text " shown."
                    ]

                admin =
                    if model.auth.localUser |> Auth.isMod id then
                        [ Route.a (Edit.Bet id Nothing |> Route.Edit) [] [ Icon.plus |> Icon.present |> Icon.view, Html.text " Add Bet" ] ]

                    else
                        []

                viewFilter title description value filter =
                    Html.div [ HtmlA.title description ]
                        [ Switch.view (Html.text title) value (SetFilter filter >> wrap |> Just) ]
            in
            [ Game.view model.zone model.time model.auth.localUser id game
            , Html.div [ HtmlA.class "controls" ]
                [ Html.div [ HtmlA.class "filter" ]
                    [ Html.span [] ((Icon.filter |> Icon.present |> Icon.view) :: shownAmount)
                    , viewFilter "Open" "Bets you can still bet on." filters.voting Voting
                    , viewFilter "Locked" "Bets that are ongoing but you can't bet on." filters.locked Locked
                    , viewFilter "Finished" "Bets that are resolved." filters.complete Complete
                    , viewFilter "Cancelled" "Bets that have been cancelled." filters.cancelled Cancelled
                    , viewFilter "Have Bet" "Bets that you have a stake in." filters.hasBet HasBet
                    , viewFilter "Spoilers" "Bets that give serious spoilers for the game." filters.spoilers Spoilers
                    ]
                ]
            , if shownBets |> List.isEmpty |> not then
                shownBets |> HtmlK.ul []

              else
                Html.p [ HtmlA.class "empty" ] [ Icon.ghost |> Icon.present |> Icon.view, Html.text "No matching bets." ]
            , Html.div [ HtmlA.class "admin" ] admin
            ]

        gameName =
            model.bets.gameBets
                |> Maybe.andThen (Tuple.second >> RemoteData.toMaybe)
                |> Maybe.map (.game >> .name)
                |> Maybe.withDefault ""

        placeBetView localUser =
            PlaceBet.view (PlaceBetMsg >> wrap) localUser model.bets.placeBet

        remoteData =
            case model.bets.gameBets of
                Just ( id, gameBets ) ->
                    gameBets |> RemoteData.map (Tuple.pair id)

                Nothing ->
                    RemoteData.Missing
    in
    { title = "Bets for “" ++ gameName ++ "”"
    , id = "bets"
    , body =
        [ remoteData |> RemoteData.view body
        , model.auth.localUser |> Maybe.map placeBetView |> Maybe.withDefault []
        ]
            |> List.concat
    }


updateFiltersFromUrl : Filters -> Model -> Model
updateFiltersFromUrl filters bets =
    filters |> filtersToPairs |> List.foldl (\( f, v ) -> updateFilters f v) bets


updateFilters : Filter -> Bool -> Model -> Model
updateFilters filter visible ({ filters } as b) =
    let
        updated =
            case filter of
                Spoilers ->
                    { filters | spoilers = Just visible }

                Voting ->
                    { filters | voting = Just visible }

                Locked ->
                    { filters | locked = Just visible }

                Complete ->
                    { filters | complete = Just visible }

                Cancelled ->
                    { filters | cancelled = Just visible }

                HasBet ->
                    { filters | hasBet = Just visible }
    in
    { b | filters = updated }
