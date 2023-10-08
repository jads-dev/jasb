module JoeBets.Page.Bets exposing
    ( init
    , load
    , update
    , view
    )

import AssocList
import Browser.Navigation as Browser
import EverySet
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Keyed as HtmlK
import JoeBets.Api as Api
import JoeBets.Api.Action as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.Path as Api
import JoeBets.Bet as Bet
import JoeBets.Bet.Editor.EditableBet as EditableBet
import JoeBets.Bet.Editor.LockMoment as LockMoment
import JoeBets.Bet.Model as Bet
import JoeBets.Bet.PlaceBet as PlaceBet
import JoeBets.Bet.PlaceBet.Model as PlaceBet
import JoeBets.Filtering as Filtering
import JoeBets.Game as Game
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game
import JoeBets.Material as Material
import JoeBets.Messages as Global
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
import Json.Encode as JsonE
import Material.Button as Button
import Material.Chips as Chips
import Material.Chips.Filter as FilterChip
import Material.Dialog as Dialog
import Material.IconButton as IconButton
import Material.Switch as Switch
import Time.Model as Time
import Util.Maybe as Maybe


wrap : Msg -> Global.Msg
wrap =
    Global.BetsMsg


type alias Parent a =
    { a
        | bets : Model
        , settings : Settings.Model
        , origin : String
        , auth : Auth.Model
        , time : Time.Context
        , navigationKey : Browser.Key
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
            , lockManager =
                { open = False
                , status = Api.initData
                , action = Api.initAction
                }
            }
    in
    storeData |> List.filterMap fromItem |> List.foldl apply model


load : Game.Id -> Subset -> Parent a -> ( Parent a, Cmd Global.Msg )
load id subset ({ bets } as model) =
    let
        end =
            case subset of
                Active ->
                    Api.Bets

                Suggestions ->
                    Api.Suggestions

        request =
            { path = Api.Game id end
            , wrap = Load id subset >> wrap
            , decoder = Game.withBetsDecoder
            }
                |> Api.get model.origin

        existingDataIfMatching gameBets =
            if id == gameBets.id then
                let
                    ( data, requestCmd ) =
                        request |> Api.getData gameBets.data
                in
                ( { gameBets | data = data }, requestCmd ) |> Just

            else
                Nothing

        insertIntoNew ( data, insertCmd ) =
            ( { id = id, subset = subset, data = data }, insertCmd )

        ( newGameBets, cmd ) =
            bets.gameBets
                |> Maybe.andThen existingDataIfMatching
                |> Maybe.withDefault (request |> Api.initGetData |> insertIntoNew)
    in
    ( { model | bets = { bets | gameBets = Just newGameBets } }
    , cmd
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


updateLockManager : (LockManager -> LockManager) -> Parent a -> Parent a
updateLockManager f ({ bets } as model) =
    { model | bets = { bets | lockManager = f model.bets.lockManager } }


update : Msg -> Parent a -> ( Parent a, Cmd Global.Msg )
update msg ({ bets, origin, time } as model) =
    case msg of
        Load loadedId loadedSubset result ->
            let
                loadIntoSelected selected =
                    { selected
                        | subset = loadedSubset
                        , data = selected.data |> Api.updateData result
                    }
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
                                updateGAndB =
                                    Game.updateByBetId betId (Bet.apply betChange |> Maybe.map)

                                applyToSelected selected =
                                    { selected | data = selected.data |> Api.mapData updateGAndB }
                            in
                            m |> updateSelected gameId applyToSelected
            in
            ( List.foldl applyChange { model | bets = bets |> PlaceBet.close } changes, Cmd.none )

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

        LockBets lockBetsMsg ->
            case lockBetsMsg of
                Open ->
                    let
                        result game =
                            let
                                ( lockStatus, cmd ) =
                                    { path = Api.Game game.id Api.LockStatus
                                    , wrap = LockBetsData >> LockBets >> wrap
                                    , decoder = gameLockStatusDecoder
                                    }
                                        |> Api.get origin
                                        |> Api.getData bets.lockManager.status

                                newLockManager lockManager =
                                    { lockManager | open = True, status = lockStatus }
                            in
                            ( model |> updateLockManager newLockManager
                            , cmd
                            )
                    in
                    bets.gameBets |> Maybe.map result |> Maybe.withDefault ( model, Cmd.none )

                LockBetsData response ->
                    let
                        newLockManager lockManager =
                            { lockManager | status = lockManager.status |> Api.updateData response }
                    in
                    ( model |> updateLockManager newLockManager
                    , Cmd.none
                    )

                Change gameTarget betTarget version locked ->
                    let
                        action =
                            if locked then
                                Api.Lock

                            else
                                Api.Unlock

                        ( actionState, request ) =
                            { path = action |> Api.Bet betTarget |> Api.Game gameTarget
                            , body = [ ( "version", JsonE.int version ) ] |> JsonE.object
                            , wrap = Changed gameTarget betTarget >> LockBets >> wrap
                            , decoder = EditableBet.decoder
                            }
                                |> Api.post origin
                                |> Api.doAction bets.lockManager.action

                        newLockManager lockManager =
                            { lockManager | action = actionState }
                    in
                    ( model |> updateLockManager newLockManager
                    , request
                    )

                Changed _ betTarget response ->
                    let
                        ( maybeUpdatedBet, actionState ) =
                            bets.lockManager.action |> Api.handleActionResult response

                        updatedLockStatusFromUpdatedBet updatedBet =
                            let
                                set _ =
                                    Just
                                        { name = updatedBet.name
                                        , locked = updatedBet.progress == EditableBet.Locked
                                        , version = updatedBet.version
                                        }

                                updateBet lockMomentStatuses =
                                    { lockMomentStatuses | lockStatus = AssocList.update betTarget set lockMomentStatuses.lockStatus }
                            in
                            AssocList.update updatedBet.lockMoment
                                (Maybe.map updateBet)

                        lockStatus =
                            case maybeUpdatedBet |> Maybe.map updatedLockStatusFromUpdatedBet of
                                Just modifyLockStatus ->
                                    bets.lockManager.status |> Api.mapData modifyLockStatus

                                Nothing ->
                                    bets.lockManager.status

                        newLockManager lockManager =
                            { lockManager | action = actionState, status = lockStatus }
                    in
                    ( model |> updateLockManager newLockManager
                    , Cmd.none
                    )

                Close ->
                    let
                        newLockManager lockManager =
                            { lockManager | open = False }

                        newModel =
                            model |> updateLockManager newLockManager
                    in
                    case bets.gameBets of
                        Just { id, subset } ->
                            load id subset newModel

                        Nothing ->
                            ( newModel, Cmd.none )


viewActiveFilters : Subset -> Filters.Resolved -> Filters -> Int -> Int -> Html Global.Msg
viewActiveFilters subset filters gameFilters totalCount shownCount =
    let
        active =
            case subset of
                Active ->
                    Filters.allFilters

                Suggestions ->
                    [ Filters.Spoilers ]

        viewFilter filter =
            let
                value =
                    Filters.value filter filters

                { title, description } =
                    Filters.describe filter
            in
            FilterChip.chip title
                |> FilterChip.button (value |> not |> SetFilter filter |> wrap |> Just)
                |> FilterChip.selected value
                |> FilterChip.attrs [ HtmlA.title description ]
                |> FilterChip.view
    in
    active |> List.map viewFilter |> Filtering.viewFilters "Bets" totalCount shownCount


view : Parent a -> Page Global.Msg
view model =
    let
        body { id, subset, data } =
            let
                game =
                    data.game

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
                    let
                        renderedBet =
                            Bet.viewFiltered
                                Global.ChangeUrl
                                model.time
                                (Bet.readWriteFromAuth (PlaceBetMsg >> wrap) model.auth)
                                subset
                                filters
                                id
                                game.name
                                betId
                                bet

                        expand b =
                            [ b ]
                                |> Html.li []
                                |> Tuple.pair (betId |> Bet.idToString)
                    in
                    renderedBet |> Maybe.map expand

                betsRendered =
                    bets
                        |> AssocList.map
                            (\_ ( n, b ) ->
                                ( n
                                , b
                                    |> AssocList.toList
                                    |> List.filterMap viewBet
                                )
                            )

                viewLockMomentBets ( lockMomentId, ( lockMomentName, lockMomentBets ) ) =
                    if lockMomentBets |> List.isEmpty then
                        Nothing

                    else
                        Just
                            ( lockMomentId |> LockMoment.idToString
                            , [ lockMomentBets |> HtmlK.ol [ HtmlA.class "bet-list" ]
                              , Html.div [ HtmlA.class "lock-moment" ]
                                    [ Html.text lockMomentName ]
                              ]
                                |> Html.li [ lockMomentId |> LockMoment.idToString |> HtmlA.id ]
                            )

                shownCount =
                    betsRendered
                        |> AssocList.values
                        |> List.map (Tuple.second >> List.length)
                        |> List.sum

                totalCount =
                    bets
                        |> AssocList.values
                        |> List.map (Tuple.second >> AssocList.size)
                        |> List.sum

                actions =
                    case subset of
                        Active ->
                            let
                                suggest =
                                    if model.auth.localUser /= Nothing then
                                        []
                                        --[ Route.a (Route.Bets Suggestions id)
                                        --    []
                                        --    [ Icon.voteYea |> Icon.view
                                        --    , Html.text " View/Make Bet Suggestions"
                                        --    ]
                                        --]

                                    else
                                        []

                                admin =
                                    if model.auth.localUser |> Auth.canManageBets id then
                                        [ Button.text "Add Bet"
                                            |> Material.buttonLink Global.ChangeUrl (Edit.Bet id Edit.New |> Route.Edit)
                                            |> Button.icon [ Icon.plus |> Icon.view ]
                                            |> Button.view
                                        , Button.text "Lock Bets"
                                            |> Button.button (LockBets Open |> wrap |> Just)
                                            |> Button.icon [ Icon.lock |> Icon.view ]
                                            |> Button.view
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
                                            [ Icon.voteYea |> Icon.view
                                            , Html.text " Make Bet Suggestion"
                                            ]
                                        ]

                                    else
                                        []
                            in
                            [ suggest ]
            in
            [ [ Html.div [ HtmlA.class "game-detail" ]
                    [ Game.view
                        Global.ChangeUrl
                        wrap
                        model.bets
                        model.time
                        model.auth.localUser
                        id
                        game
                    , Game.viewManagers game
                    , lockStatusDialog id model.bets.lockManager
                    ]
              , Html.div [ HtmlA.class "controls" ] [ viewActiveFilters subset filters gameFilters totalCount shownCount ]
              , if shownCount > 0 then
                    betsRendered
                        |> AssocList.toList
                        |> List.filterMap viewLockMomentBets
                        |> HtmlK.ol [ HtmlA.class "lock-moments" ]

                else
                    Html.p [ HtmlA.class "empty" ] [ Icon.ghost |> Icon.view, Html.span [] [ Html.text "No matching bets." ] ]
              , Html.ul [ HtmlA.class "final-actions" ]
                    (actions |> List.concat |> List.map (List.singleton >> Html.li []))
              ]
            , model.auth.localUser |> Maybe.map placeBetView |> Maybe.withDefault []
            ]
                |> List.concat

        gameName =
            model.bets.gameBets
                |> Maybe.andThen (.data >> Api.dataToMaybe)
                |> Maybe.map (.game >> .name)
                |> Maybe.withDefault ""

        placeBetView localUser =
            PlaceBet.view (PlaceBetMsg >> wrap) localUser model.bets.placeBet

        remoteData =
            case model.bets.gameBets of
                Just { id, subset, data } ->
                    data |> Api.mapData (\d -> { id = id, subset = subset, data = d })

                Nothing ->
                    Api.initData
    in
    { title = "Bets for “" ++ gameName ++ "”"
    , id = "bets"
    , body = remoteData |> Api.viewData Api.viewOrError body
    }


viewLockStatus : Game.Id -> Api.ActionState -> GameLockStatus -> List (Html Global.Msg)
viewLockStatus gameId lockAction lockStatus =
    let
        linkify name betId =
            Route.a (Route.Bet gameId betId)
                [ HtmlA.class "permalink" ]
                [ Html.text name
                , Icon.link |> Icon.view
                ]

        viewBet ( id, { name, locked, version } ) =
            Html.li [ HtmlA.class "bet" ]
                [ Html.span [ HtmlA.class "name" ] [ linkify name id ]
                , Html.span [ HtmlA.class "locked" ]
                    [ Switch.switch
                        (Change gameId id version >> LockBets >> wrap |> Just |> Api.ifNotWorking lockAction)
                        locked
                        |> Switch.view
                    ]
                ]

        viewLockMomentBets ( lockMomentId, details ) =
            let
                content =
                    if AssocList.isEmpty details.lockStatus then
                        [ Html.li [ HtmlA.class "empty" ] [ Html.div [] [ Icon.ghost |> Icon.view, Html.span [] [ Html.text " No bets for lock moment." ] ] ] ]

                    else
                        details.lockStatus |> AssocList.toList |> List.map viewBet
            in
            Html.li [ HtmlA.class "lock-moment" ]
                [ Html.span [ HtmlA.class "name" ]
                    [ Html.text "Locks at “", Html.text details.lockMoment.name, Html.text "”:" ]
                ]
                :: content

        header =
            Html.li [ HtmlA.class "header" ]
                [ Html.span [ HtmlA.class "name" ] [ Html.text "Bet" ]
                , Html.span [ HtmlA.class "locked" ] [ Html.text "Lock" ]
                ]

        bets =
            lockStatus |> AssocList.toList |> List.concatMap viewLockMomentBets
    in
    [ header :: bets |> Html.ol [] ]


lockStatusDialog : Game.Id -> LockManager -> Html Global.Msg
lockStatusDialog id { open, status, action } =
    Dialog.dialog (LockBets Close |> wrap)
        (status |> Api.viewData Api.viewOrError (viewLockStatus id action))
        [ Button.text "Close"
            |> Button.button (LockBets Close |> wrap |> Just)
            |> Button.icon [ Icon.times |> Icon.view ]
            |> Button.view
        ]
        open
        |> Dialog.headline [ Html.text "Change Lock Status" ]
        |> Dialog.attrs [ HtmlA.id "lock-manager" ]
        |> Dialog.view


apply : StoreChange -> Model -> Model
apply change model =
    case change of
        FiltersItem gameId item ->
            { model | filters = model.filters |> AssocList.insert gameId item }

        FavouritesItem favourites ->
            { model | favourites = favourites }
