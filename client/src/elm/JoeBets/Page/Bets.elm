module JoeBets.Page.Bets exposing
    ( init
    , load
    , update
    , view
    )

import AssocList
import Browser.Navigation as Navigation
import EverySet
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
import JoeBets.Bet.PlaceBet.Model as PlaceBet
import JoeBets.Game as Game
import JoeBets.Game.Model as Game
import JoeBets.Page exposing (Page)
import JoeBets.Page.Bets.Filters as Filters exposing (Filters)
import JoeBets.Page.Bets.Model exposing (..)
import JoeBets.Page.Edit.Model as Edit
import JoeBets.Page.User.Model as User
import JoeBets.Route as Route
import JoeBets.Settings.Model as Settings
import JoeBets.Store as Store
import JoeBets.Store.Codecs as Codecs
import JoeBets.Store.Item as Item
import JoeBets.Store.KeyedItem as Store exposing (KeyedItem)
import JoeBets.User.Auth as User
import JoeBets.User.Auth.Model as Auth
import Material.IconButton as IconButton
import Material.Switch as Switch
import Time.Model as Time
import Util.Maybe as Maybe
import Util.RemoteData as RemoteData exposing (RemoteData)


type alias Parent a =
    { a
        | bets : Model
        , settings : Settings.Model
        , origin : String
        , auth : Auth.Model
        , time : Time.Context
        , navigationKey : Navigation.Key
    }


init : List KeyedItem -> Model
init storeData =
    let
        fromItem keyedItem =
            case keyedItem of
                Store.BetsItem change ->
                    Just change

                _ ->
                    Nothing

        model =
            { gameBets = Nothing
            , placeBet = PlaceBet.init
            , filters = AssocList.empty
            , favourites = Item.default Codecs.gameFavourites
            }
    in
    storeData |> List.filterMap fromItem |> List.foldl apply model


load : (Msg -> msg) -> Game.Id -> Subset -> Parent a -> ( Parent a, Cmd msg )
load wrap id subset ({ bets, settings } as model) =
    let
        newBets =
            if Just id /= (bets.gameBets |> Maybe.map .id) then
                { bets | gameBets = Just { id = id, subset = subset, data = RemoteData.Missing } }

            else
                bets

        end =
            case subset of
                Active ->
                    Api.Bets

                Suggestions ->
                    Api.Suggestions
    in
    ( { model | bets = newBets }
    , Api.get model.origin
        { path = Api.Game id end
        , expect = Http.expectJson (Load id subset >> wrap) gameBetsDecoder
        }
    )


updateSelected : Game.Id -> (Selected -> Selected) -> { parent | bets : Model } -> { parent | bets : Model }
updateSelected gameId change ({ bets } as model) =
    let
        changeIfGameMatches selected =
            if selected.id == gameId then
                change selected

            else
                selected
    in
    { model | bets = { bets | gameBets = bets.gameBets |> Maybe.map changeIfGameMatches } }


update : (Msg -> msg) -> Msg -> Parent a -> ( Parent a, Cmd msg )
update wrap msg ({ bets, settings, origin, time } as model) =
    case msg of
        Load loadedId loadedSubset result ->
            let
                loadIntoSelected selected =
                    { selected | subset = loadedSubset, data = RemoteData.load result }
            in
            ( updateSelected loadedId loadIntoSelected model, Cmd.none )

        PlaceBetMsg placeBetMsg ->
            let
                ( newBets, cmd ) =
                    PlaceBet.update (PlaceBetMsg >> wrap)
                        (Apply >> wrap)
                        origin
                        time
                        placeBetMsg
                        bets
            in
            ( { model | bets = newBets }, cmd )

        Apply changes ->
            let
                applyChange change m =
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
                                    { gAndB | bets = gAndB.bets |> AssocList.update betId (betChange |> Bet.apply >> Maybe.map) }

                                applyToSelected selected =
                                    { selected | data = selected.data |> RemoteData.map updateGAndB }
                            in
                            m |> updateSelected gameId applyToSelected
            in
            ( List.foldl applyChange { model | bets = { bets | placeBet = Nothing } } changes, Cmd.none )

        SetFilter filter visible ->
            case bets.gameBets of
                Just { id } ->
                    let
                        codec =
                            Codecs.gameFilters id

                        existing =
                            bets.filters
                                |> AssocList.get id
                                |> Maybe.withDefault (Item.default codec)

                        setGameFilters =
                            existing.value |> Filters.update filter visible |> Store.set codec (Just existing)
                    in
                    ( model, setGameFilters )

                Nothing ->
                    ( model, Cmd.none )

        ClearFilters ->
            case bets.gameBets of
                Just { id } ->
                    let
                        codec =
                            Codecs.gameFilters id

                        existing =
                            bets.filters
                                |> AssocList.get id
                                |> Maybe.withDefault (Item.default codec)
                    in
                    ( model, Store.delete codec (Just existing) )

                Nothing ->
                    ( model, Cmd.none )

        SetFavourite gameId favourite ->
            let
                old =
                    model.bets.favourites

                setFavourite =
                    if favourite then
                        EverySet.insert

                    else
                        EverySet.remove
            in
            ( model
            , Store.setOrDelete Codecs.gameFavourites
                (Just old)
                (old.value |> setFavourite gameId |> Maybe.ifFalse EverySet.isEmpty)
            )

        ReceiveStoreChange change ->
            ( { model | bets = apply change bets }, Cmd.none )


viewActiveFilters : (Msg -> msg) -> Subset -> Filters.Resolved -> Filters -> List (Html msg) -> Html msg
viewActiveFilters wrap subset filters gameFilters shownAmount =
    let
        active =
            case subset of
                Active ->
                    Filters.allFilters

                Suggestions ->
                    [ Filters.Spoilers ]

        viewFilter filter =
            let
                ( title, description, value ) =
                    case filter of
                        Filters.Voting ->
                            ( "Open", "Bets you can still bet on.", filters.voting )

                        Filters.Locked ->
                            ( "Locked", "Bets that are ongoing but you can't bet on.", filters.locked )

                        Filters.Complete ->
                            ( "Finished", "Bets that are resolved.", filters.complete )

                        Filters.Cancelled ->
                            ( "Cancelled", "Bets that have been cancelled.", filters.cancelled )

                        Filters.HasBet ->
                            ( "Have Bet", "Bets that you have a stake in.", filters.hasBet )

                        Filters.Spoilers ->
                            ( "Spoilers", "Bets that give serious spoilers for the game.", filters.spoilers )
            in
            Html.div [ HtmlA.title description ]
                [ Switch.view (Html.text title) value (SetFilter filter >> wrap |> Just) ]
    in
    [ [ Html.span [] ((Icon.filter |> Icon.present |> Icon.view) :: shownAmount) ]
    , active |> List.map viewFilter
    , [ IconButton.view (Icon.backspace |> Icon.present |> Icon.view)
            "Reset filters to default."
            (ClearFilters |> wrap |> Maybe.when (gameFilters |> Filters.any))
      ]
    ]
        |> List.concat
        |> Html.div [ HtmlA.class "filter" ]


view : (Msg -> msg) -> Parent a -> Page msg
view wrap model =
    let
        body { id, subset, data } =
            let
                game =
                    data.game.game

                details =
                    data.game.details

                bets =
                    data.bets

                gameFilters =
                    model.bets.filters
                        |> AssocList.get id
                        |> Maybe.map .value
                        |> Maybe.withDefault Filters.init

                filters =
                    model.settings.defaultFilters.value
                        |> Filters.merge gameFilters
                        |> Filters.resolveDefaults

                viewBet ( betId, bet ) =
                    Bet.viewFiltered model.time
                        (Bet.voteAsFromAuth (PlaceBetMsg >> wrap) model.auth)
                        subset
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

                actions =
                    case subset of
                        Active ->
                            let
                                suggest =
                                    if model.auth.localUser /= Nothing then
                                        []
                                        --[ Route.a (Route.Bets Suggestions id)
                                        --    []
                                        --    [ Icon.voteYea |> Icon.present |> Icon.view
                                        --    , Html.text " View/Make Bet Suggestions"
                                        --    ]
                                        --]

                                    else
                                        []

                                admin =
                                    if model.auth.localUser |> Auth.isMod id then
                                        [ Route.a (Edit.Bet id Edit.New |> Route.Edit)
                                            []
                                            [ Icon.plus |> Icon.present |> Icon.view, Html.text " Add Bet" ]
                                        ]

                                    else
                                        []
                            in
                            [ suggest, admin ]

                        Suggestions ->
                            let
                                suggest =
                                    if model.auth.localUser /= Nothing then
                                        [ Route.a (Edit.Bet id Edit.Suggest |> Route.Edit)
                                            []
                                            [ Icon.voteYea |> Icon.present |> Icon.view
                                            , Html.text " Make Bet Suggestion"
                                            ]
                                        ]

                                    else
                                        []
                            in
                            [ suggest ]
            in
            [ Game.view wrap model.bets model.time model.auth.localUser id game (Just details)
            , Html.div [ HtmlA.class "controls" ] [ viewActiveFilters wrap subset filters gameFilters shownAmount ]
            , if shownBets |> List.isEmpty |> not then
                shownBets |> HtmlK.ul [ HtmlA.class "bet-list" ]

              else
                Html.p [ HtmlA.class "empty" ] [ Icon.ghost |> Icon.present |> Icon.view, Html.text "No matching bets." ]
            , Html.ul [ HtmlA.class "final-actions" ]
                (actions |> List.concat |> List.map (List.singleton >> Html.li []))
            ]

        gameName =
            model.bets.gameBets
                |> Maybe.andThen (.data >> RemoteData.toMaybe)
                |> Maybe.map (.game >> .game >> .name)
                |> Maybe.withDefault ""

        placeBetView localUser =
            PlaceBet.view (PlaceBetMsg >> wrap) localUser model.bets.placeBet

        remoteData =
            case model.bets.gameBets of
                Just { id, subset, data } ->
                    data |> RemoteData.map (\d -> { id = id, subset = subset, data = d })

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


apply : StoreChange -> Model -> Model
apply change model =
    case change of
        FiltersItem gameId item ->
            { model | filters = model.filters |> AssocList.insert gameId item }

        FavouritesItem favourites ->
            { model | favourites = favourites }
