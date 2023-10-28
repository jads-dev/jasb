module JoeBets.Page.Gacha.Collection exposing
    ( init
    , load
    , manageContext
    , onAuthChange
    , update
    , view
    )

import AssocList
import Browser.Dom as Dom
import DragDrop
import EverySet
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Keyed as HtmlK
import JoeBets.Api as Api
import JoeBets.Api.Action as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.Error as Api
import JoeBets.Api.IdData as Api
import JoeBets.Api.Model as Api
import JoeBets.Api.Path as Api
import JoeBets.Gacha.Balance as Balance
import JoeBets.Gacha.Banner as Banner
import JoeBets.Gacha.Card as Card
import JoeBets.Gacha.Context as Gacha
import JoeBets.Messages as Global
import JoeBets.Page exposing (Page)
import JoeBets.Page.Gacha.Balance as Balance
import JoeBets.Page.Gacha.Banner as Banner
import JoeBets.Page.Gacha.Card as Card
import JoeBets.Page.Gacha.Collection.Filters exposing (..)
import JoeBets.Page.Gacha.Collection.Filters.Model exposing (..)
import JoeBets.Page.Gacha.Collection.Model exposing (..)
import JoeBets.Page.Gacha.Collection.Route exposing (..)
import JoeBets.Page.Gacha.DetailedCard as Gacha
import JoeBets.Page.Gacha.Model as Gacha
import JoeBets.Route as Route
import JoeBets.User as User
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Model as User
import Json.Encode as JsonE
import List.Extra as List
import Material.Button as Button
import Material.Dialog as Dialog
import Material.IconButton as IconButton
import Platform.Cmd as Cmd
import Task
import Time.Model as Time
import Util.AssocList as AssocList
import Util.EverySet as EverySet
import Util.Maybe as Maybe


wrap : Msg -> Global.Msg
wrap =
    Global.CollectionMsg


wrapGacha : Gacha.Msg -> Global.Msg
wrapGacha =
    Global.GachaMsg


type alias Parent a =
    { a
        | origin : String
        , time : Time.Context
        , auth : Auth.Model
        , collection : Model
        , gacha : Gacha.Model
    }


init : Model
init =
    { overview = Api.initIdData
    , cards = Api.initIdData
    , recycleConfirmation = Nothing
    , messageEditor = Nothing
    , orderEditor = DragDrop.init
    , saving = Api.initAction
    , editingHighlights = False
    , filters = defaultFilters
    }


loadOverview : String -> User.Id -> Api.IdData User.Id CollectionOverview -> ( Api.IdData User.Id CollectionOverview, Cmd Global.Msg )
loadOverview origin userId overview =
    { path = Api.UserCardsOverview |> Api.UserCards |> Api.Cards userId |> Api.Gacha
    , decoder = overviewDecoder
    , wrap = LoadCollection userId >> wrap
    }
        |> Api.get origin
        |> Api.getIdDataIfMissing userId overview


loadOverviewIfSelf : String -> User.Id -> Auth.Model -> Api.IdData User.Id CollectionOverview -> ( Api.IdData User.Id CollectionOverview, Cmd Global.Msg )
loadOverviewIfSelf origin userId { localUser } overview =
    if (localUser |> Maybe.map .id) == Just userId then
        loadOverview origin userId overview

    else
        ( overview, Cmd.none )


onAuthChange : User.Id -> Route -> Parent a -> ( Parent a, Cmd Global.Msg )
onAuthChange id _ ({ origin, auth, collection } as parent) =
    let
        ( newOverview, overviewCmd ) =
            loadOverviewIfSelf origin id auth collection.overview
    in
    ( { parent | collection = { collection | overview = newOverview } }, overviewCmd )


load : User.Id -> Route -> Parent a -> ( Parent a, Cmd Global.Msg )
load id route ({ origin, auth, gacha, collection } as model) =
    let
        ( context, contextCmd ) =
            Gacha.loadContextIfNeeded origin gacha.context

        loadBannerCards bannerId =
            let
                ( newBannerCollection, bannerCollectionCmd ) =
                    { path = bannerId |> Api.UserCardsInBanner |> Api.UserCards |> Api.Cards id |> Api.Gacha
                    , decoder = bannerCollectionDecoder
                    , wrap = (bannerId |> Just |> LoadCards id) >> wrap
                    }
                        |> Api.get origin
                        |> Api.getIdData ( id, Just bannerId ) collection.cards

                ( newOverview, overviewCmd ) =
                    loadOverviewIfSelf origin id auth collection.overview
            in
            ( { collection
                | overview = newOverview
                , cards = newBannerCollection
              }
            , Cmd.batch [ bannerCollectionCmd, overviewCmd ]
            )

        ( newCollection, newGacha, cmds ) =
            case route of
                Overview ->
                    let
                        ( newOverview, overviewCmd ) =
                            loadOverview origin id collection.overview
                    in
                    ( { collection | overview = newOverview }, gacha, overviewCmd )

                All ->
                    let
                        ( newCards, cardsCmd ) =
                            { path = Api.AllUserCards |> Api.UserCards |> Api.Cards id |> Api.Gacha
                            , decoder = allCollectionDecoder
                            , wrap = LoadCards id Nothing >> wrap
                            }
                                |> Api.get origin
                                |> Api.getIdData ( id, Nothing ) collection.cards

                        ( newOverview, overviewCmd ) =
                            loadOverviewIfSelf origin id auth collection.overview
                    in
                    ( { collection
                        | overview = newOverview
                        , cards = newCards
                      }
                    , gacha
                    , Cmd.batch [ cardsCmd, overviewCmd ]
                    )

                Banner bannerId ->
                    let
                        ( loadedCollection, loadedCmd ) =
                            loadBannerCards bannerId
                    in
                    ( loadedCollection, gacha, loadedCmd )

                Card bannerId cardId ->
                    let
                        ( loadedCollection, loadedCmd ) =
                            loadBannerCards bannerId

                        ( loadedGacha, gachaCmd ) =
                            Gacha.viewDetailedCard origin
                                { ownerId = id, bannerId = bannerId, cardId = cardId }
                                gacha
                    in
                    ( loadedCollection
                    , loadedGacha
                    , Cmd.batch [ loadedCmd, gachaCmd ]
                    )
    in
    ( { model
        | collection = newCollection
        , gacha = { newGacha | context = context }
      }
    , Cmd.batch [ contextCmd, cmds ]
    )


update : Msg -> Parent a -> ( Parent a, Cmd Global.Msg )
update msg ({ origin, collection } as model) =
    case msg of
        LoadCollection userId response ->
            let
                updatedOverview =
                    collection.overview |> Api.updateIdData userId response
            in
            ( { model
                | collection =
                    { collection | overview = updatedOverview }
              }
            , Cmd.none
            )

        LoadCards userId bannerId response ->
            let
                updatedCards =
                    collection.cards |> Api.updateIdData ( userId, bannerId ) response
            in
            ( { model
                | collection =
                    { collection | cards = updatedCards }
              }
            , Cmd.none
            )

        SetEditingHighlights editing ->
            case model.auth.localUser of
                Just { id } ->
                    let
                        revertOrderInCollection c =
                            { c | highlights = c.highlights |> revertOrder }

                        updatedCollection =
                            if not editing then
                                Api.updateIdDataValue id revertOrderInCollection

                            else
                                identity
                    in
                    ( { model
                        | collection =
                            { collection
                                | overview = collection.overview |> updatedCollection
                                , editingHighlights = editing
                            }
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        SetCardHighlighted user banner card highlighted ->
            let
                path =
                    Api.SpecificCard banner card Api.Highlight
                        |> Api.Cards user
                        |> Api.Gacha

                wrapSaved =
                    HighlightSaved user banner card >> wrap

                execute =
                    if highlighted then
                        Api.put model.origin
                            { path = path
                            , body = JsonE.object []
                            , wrap = Result.map Just >> wrapSaved
                            , decoder = Card.highlightedDecoder
                            }

                    else
                        Api.delete model.origin
                            { path = path
                            , wrap = Result.map (\_ -> Nothing) >> wrapSaved
                            , decoder = Card.idDecoder
                            }

                ( saving, cmd ) =
                    execute |> Api.doAction collection.saving
            in
            ( { model | collection = { collection | saving = saving } }
            , cmd
            )

        EditHighlightMessage user _ card message ->
            let
                updateMessageEditor existingEditor givenMessage =
                    case existingEditor of
                        Just editor ->
                            if editor.card == card then
                                { editor | message = givenMessage }

                            else
                                editor

                        Nothing ->
                            { card = card, message = givenMessage }

                updatedCollection =
                    if Api.toMaybeId collection.overview == Just user then
                        { collection | messageEditor = message |> Maybe.map (updateMessageEditor collection.messageEditor) }

                    else
                        collection
            in
            ( { model | collection = updatedCollection }
            , if message == Nothing then
                Cmd.none

              else
                Dom.focus "highlighted-message-editor"
                    |> Task.attempt (\_ -> "Focus highlighted message editor done." |> NoOp |> wrap)
            )

        SetHighlightMessage user banner card message ->
            let
                ( saving, saveCmd ) =
                    { path =
                        Api.SpecificCard banner card Api.Highlight
                            |> Api.Cards user
                            |> Api.Gacha
                    , body =
                        [ ( "message", message |> Maybe.map JsonE.string |> Maybe.withDefault JsonE.null ) ]
                            |> JsonE.object
                    , wrap = Result.map Just >> HighlightSaved user banner card >> wrap
                    , decoder = Card.highlightedDecoder
                    }
                        |> Api.post origin
                        |> Api.doAction collection.saving
            in
            ( { model | collection = { collection | saving = saving } }
            , saveCmd
            )

        HighlightSaved user banner card response ->
            let
                ( maybeUpdatedHighlight, state ) =
                    collection.saving |> Api.handleActionResult response

                updateHighlights c =
                    case maybeUpdatedHighlight of
                        Just updatedHighlight ->
                            let
                                op =
                                    case updatedHighlight of
                                        Just addedOrReplaced ->
                                            replaceOrAddHighlight banner card addedOrReplaced

                                        Nothing ->
                                            removeHighlight card
                            in
                            { c | highlights = op c.highlights }

                        Nothing ->
                            c

                updatedCollection =
                    if Api.toMaybeId collection.overview == Just user then
                        let
                            newCollection =
                                collection.overview
                                    |> Api.updateIdDataValue user updateHighlights
                        in
                        { collection
                            | saving = state
                            , overview = newCollection
                            , messageEditor = Nothing
                        }

                    else
                        collection
            in
            ( { model | collection = updatedCollection }, Cmd.none )

        ReorderHighlights user dragDropMsg ->
            let
                updatedCollection =
                    if Api.toMaybeId collection.overview == Just user then
                        let
                            orderEditor =
                                collection.orderEditor

                            ( newOrderEditor, drop ) =
                                DragDrop.update dragDropMsg orderEditor

                            updateOrder ( cardId, index ) c =
                                let
                                    ( before, after ) =
                                        c.highlights
                                            |> getLocalOrder
                                            |> List.filter ((/=) cardId)
                                            |> List.splitAt index

                                    newOrder =
                                        List.concat [ before, [ cardId ], after ]
                                in
                                { c | highlights = c.highlights |> reorder newOrder }

                            updateIfDropped =
                                case drop of
                                    Just dropped ->
                                        Api.updateIdDataValue user (updateOrder dropped)

                                    Nothing ->
                                        identity
                        in
                        { collection
                            | orderEditor = newOrderEditor
                            , overview = collection.overview |> updateIfDropped
                        }

                    else
                        collection
            in
            ( { model | collection = updatedCollection }, Cmd.none )

        SaveHighlightOrder user cardOrder maybeResult ->
            case maybeResult of
                Nothing ->
                    let
                        ( saving, saveOrderCmd ) =
                            { path = Api.Highlights |> Api.Cards user |> Api.Gacha
                            , body = cardOrder |> JsonE.list Card.encodeId
                            , wrap = Just >> SaveHighlightOrder user cardOrder >> wrap
                            , decoder = Card.highlightsDecoder
                            }
                                |> Api.post origin
                                |> Api.doAction collection.saving
                    in
                    ( { model | collection = { collection | saving = saving } }
                    , saveOrderCmd
                    )

                Just result ->
                    let
                        ( maybeUpdatedHighlights, state ) =
                            collection.saving |> Api.handleActionResult result

                        replaceCollection newHighlights existing =
                            { existing | highlights = localOrderHighlights newHighlights }

                        ( withUpdatedHighlights, editingHighlights ) =
                            case maybeUpdatedHighlights of
                                Just newHighlights ->
                                    ( Api.updateIdDataValue user (replaceCollection newHighlights)
                                    , False
                                    )

                                Nothing ->
                                    ( identity, collection.editingHighlights )
                    in
                    ( { model
                        | collection =
                            { collection
                                | overview = collection.overview |> withUpdatedHighlights
                                , saving = state
                                , editingHighlights = editingHighlights
                            }
                      }
                    , Cmd.none
                    )

        RecycleCard user banner card process ->
            let
                gacha =
                    model.gacha

                ( updatedGacha, updatedCollection, actionCmd ) =
                    case process of
                        AskConfirmRecycle ->
                            let
                                ( value, getValue ) =
                                    { path =
                                        Api.RecycleValue
                                            |> Api.SpecificCard banner card
                                            |> Api.Cards user
                                            |> Api.Gacha
                                    , wrap = GetRecycleValue >> RecycleCard user banner card >> wrap
                                    , decoder = Balance.valueDecoder
                                    }
                                        |> Api.get origin
                                        |> Api.initGetData
                            in
                            ( gacha
                            , { collection
                                | recycleConfirmation =
                                    Just
                                        { banner = banner
                                        , card = card
                                        , value = value
                                        }
                              }
                            , getValue
                            )

                        GetRecycleValue response ->
                            let
                                updateExisting existing =
                                    if existing.banner == banner && existing.card == card then
                                        { existing | value = existing.value |> Api.updateData response }

                                    else
                                        existing
                            in
                            ( gacha
                            , { collection
                                | recycleConfirmation =
                                    collection.recycleConfirmation |> Maybe.map updateExisting
                              }
                            , Cmd.none
                            )

                        ExecuteRecycle ->
                            let
                                ( saving, cmd ) =
                                    { path =
                                        Api.SpecificCard banner card Api.Card
                                            |> Api.Cards user
                                            |> Api.Gacha
                                    , wrap = Recycled >> RecycleCard user banner card >> wrap
                                    , decoder = Balance.decoder
                                    }
                                        |> Api.delete origin
                                        |> Api.doAction collection.saving
                            in
                            ( gacha
                            , { collection | saving = saving }
                            , cmd
                            )

                        Recycled response ->
                            let
                                -- Ignored because we use updateData lower down.
                                ( _, saving ) =
                                    collection.saving
                                        |> Api.handleActionResult response

                                updateCards _ ct =
                                    { ct | cards = ct.cards |> AssocList.remove card }

                                updateCardTypes bannerCollection =
                                    { bannerCollection
                                        | cardTypes =
                                            bannerCollection.cardTypes
                                                |> AssocList.map updateCards
                                    }

                                updateConfirmationAndCards =
                                    { collection
                                        | cards =
                                            collection.cards
                                                |> Api.updateIdDataValue ( user, Just banner ) updateCardTypes
                                                |> Api.updateIdDataValue ( user, Nothing ) updateCardTypes
                                        , recycleConfirmation = Nothing
                                    }
                            in
                            ( { gacha
                                | balance = gacha.balance |> Api.updateData response
                                , detailedCard = Gacha.closeDetailDialog gacha.detailedCard
                              }
                            , { updateConfirmationAndCards | saving = saving }
                            , Cmd.none
                            )
            in
            ( { model
                | collection = updatedCollection
                , gacha = updatedGacha
              }
            , actionCmd
            )

        CancelRecycle ->
            ( { model | collection = { collection | recycleConfirmation = Nothing } }
            , Cmd.none
            )

        ToggleFilter filter ->
            let
                updateFilters filters =
                    case filter of
                        Ownership ownershipFilter ->
                            { filters | ownership = filters.ownership |> EverySet.toggle ownershipFilter }

                        Quality qualityFilter ->
                            { filters | quality = filters.quality |> Maybe.map (EverySet.toggle qualityFilter) }

                        Rarity rarityFilter ->
                            { filters | rarity = filters.rarity |> Maybe.map (EverySet.toggle rarityFilter) }
            in
            ( { model | collection = { collection | filters = collection.filters |> updateFilters } }
            , Cmd.none
            )

        ShowQualityFilters show ->
            let
                updateFilters filterModel =
                    { filterModel
                        | quality =
                            if show then
                                Just EverySet.empty

                            else
                                Nothing
                    }
            in
            ( { model | collection = { collection | filters = collection.filters |> updateFilters } }
            , Cmd.none
            )

        ShowRarityFilters show ->
            let
                updateFilters filterModel =
                    { filterModel
                        | rarity =
                            if show then
                                Just EverySet.empty

                            else
                                Nothing
                    }
            in
            ( { model | collection = { collection | filters = collection.filters |> updateFilters } }
            , Cmd.none
            )

        NoOp _ ->
            ( model, Cmd.none )


manageContext : Auth.Model -> Model -> Maybe ManageContext
manageContext auth { orderEditor, overview } =
    let
        contextFor ( id, { highlights } ) localUser =
            if id == localUser.id then
                Just
                    { orderEditor = orderEditor
                    , highlighted =
                        highlights
                            |> getHighlights
                            |> AssocList.keySet
                    }

            else
                Nothing
    in
    Maybe.map2 contextFor
        (Api.idDataToMaybe overview)
        auth.localUser
        |> Maybe.andThen identity


viewHighlights : Maybe ManageContext -> Maybe (User.Id -> Banner.Id -> Card.Id -> Global.Msg) -> Model -> CollectionOverview -> List (Html Global.Msg)
viewHighlights maybeContext onClick model collection =
    let
        order =
            collection.highlights |> getLocalOrder

        highlights =
            collection.highlights |> getHighlights

        ( description, manageOrView ) =
            if model.editingHighlights then
                ( [ Html.p [] [ Html.text "Drag and drop cards to reorder them." ] ]
                , Card.Manage maybeContext
                )

            else
                ( [], Card.View onClick )

        cards =
            if AssocList.size highlights > 0 then
                let
                    viewHighlight =
                        Card.viewHighlight manageOrView
                            model
                            collection.user.id
                            collection.highlights

                    fromId id =
                        AssocList.get id highlights |> Maybe.map (Tuple.pair id)
                in
                order
                    |> List.filterMap fromId
                    |> List.indexedMap viewHighlight
                    |> HtmlK.ol [ HtmlA.class "cards" ]

            else
                Html.p [ HtmlA.class "empty" ]
                    [ Icon.ghost |> Icon.view
                    , Html.span [] [ Html.text "This user has not showcased any cards." ]
                    ]

        ( saveOrder, editButton ) =
            case maybeContext of
                Just _ ->
                    let
                        orderChanged =
                            isOrderChanged collection.highlights

                        startEditingHighlights =
                            SetEditingHighlights (not model.editingHighlights)
                                |> wrap
                                |> Maybe.whenNot (model.editingHighlights && orderChanged)
                    in
                    ( if model.editingHighlights then
                        let
                            saveAction =
                                SaveHighlightOrder collection.user.id order Nothing
                                    |> wrap
                                    |> Maybe.when orderChanged
                        in
                        [ Html.div [ HtmlA.class "controls" ]
                            [ Button.text "Cancel"
                                |> Button.button (SetEditingHighlights False |> wrap |> Just |> Api.ifNotWorking model.saving)
                                |> Button.icon [ Icon.undo |> Icon.view ]
                                |> Button.view
                            , Button.filled "Save Order"
                                |> Button.button (saveAction |> Api.ifNotWorking model.saving)
                                |> Button.icon [ Icon.save |> Icon.view |> Api.orSpinner model.saving ]
                                |> Button.view
                            ]
                        ]

                      else
                        []
                    , [ IconButton.icon (Icon.view Icon.edit)
                            "Edit"
                            |> IconButton.button startEditingHighlights
                            |> IconButton.view
                      ]
                    )

                _ ->
                    ( [], [] )
    in
    [ [ [ Html.div [ HtmlA.class "header" ]
            (Html.h3 [] [ Html.text "Showcased Cards" ] :: editButton)
        ]
      , description
      , model.saving
            |> Api.toMaybeError
            |> Maybe.map (\e -> [ Api.viewError e ])
            |> Maybe.withDefault []
      , [ cards ]
      , saveOrder
      ]
        |> List.concat
        |> Html.div [ HtmlA.class "highlights" ]
    ]


view : User.Id -> Route -> Parent a -> Page Global.Msg
view userId route parent =
    let
        titleFromDataInternal target ( id, { user } ) =
            if id == target then
                user.user.name ++ "'s Cards" |> Just

            else
                Nothing

        titleFromData target =
            Api.idDataToMaybe >> Maybe.andThen (titleFromDataInternal target)

        maybeContext =
            manageContext parent.auth parent.collection

        confirmRecycle =
            let
                ( confirmContent, confirmAction ) =
                    case parent.collection.recycleConfirmation of
                        Just { banner, card, value } ->
                            let
                                saving =
                                    parent.collection.saving

                                viewedValue =
                                    value
                                        |> Api.dataToMaybe
                                        |> Maybe.map Balance.viewValue
                                        |> Maybe.withDefault (Html.text "scrap proportional to the rarity")
                            in
                            ( [ [ Html.p []
                                    [ Html.text "Are you sure you want to recycle this card? "
                                    , Html.text "There is no way to undo this, it will be gone forever. "
                                    , Html.text "You will get "
                                    , viewedValue
                                    , Html.text " for recycling the card."
                                    ]
                                ]
                              , Api.viewAction [] saving
                              ]
                                |> List.concat
                            , RecycleCard userId banner card ExecuteRecycle |> wrap |> Just |> Api.ifNotWorking saving
                            )

                        Nothing ->
                            ( [], Nothing )
            in
            Dialog.dialog (CancelRecycle |> wrap)
                confirmContent
                [ Html.span [ HtmlA.class "cancel" ]
                    [ Button.text "Cancel"
                        |> Button.button (CancelRecycle |> wrap |> Just)
                        |> Button.icon [ Icon.times |> Icon.view ]
                        |> Button.view
                    ]
                , Button.filled "Recycle"
                    |> Button.button confirmAction
                    |> Button.icon [ Icon.recycle |> Icon.view ]
                    |> Button.view
                ]
                (parent.collection.recycleConfirmation /= Nothing)
                |> Dialog.headline [ Html.text "Confirm Recycling" ]
                |> Dialog.alert
                |> Dialog.attrs [ HtmlA.id "confirm-recycle-dialog" ]
                |> Dialog.view

        viewDetailedCard ownerId bannerId card =
            Gacha.ViewDetailedCard
                { ownerId = ownerId, bannerId = bannerId, cardId = card }
                Api.Start
                |> wrapGacha

        viewCollection : Model -> User.Id -> CollectionOverview -> List (Html Global.Msg)
        viewCollection model targetId collection =
            let
                { user } =
                    collection.user
            in
            [ [ User.viewLink User.Full targetId user ]
            , viewHighlights maybeContext (viewDetailedCard |> Just) model collection
            , [ Route.a (All |> Route.CardCollection targetId)
                    []
                    [ Html.text "View All "
                    , User.viewName user
                    , Html.text "'s Cards"
                    ]
              , Html.h3 [] [ Html.text "Cards by Banner" ]
              , Banner.viewCollectionBanners collection.user.id collection.banners
              , confirmRecycle
              , Card.viewDetailedCardDialog maybeContext parent.gacha
              , Card.viewDetailedCardTypeDialog parent.gacha
              ]
            ]
                |> List.concat

        viewCollectionCards _ collectionCards =
            let
                targetUserId =
                    collectionCards.user.id

                { user } =
                    collectionCards.user

                viewBanner banner =
                    [ Banner.viewCollectionBanner False userId banner.id banner.banner ]

                viewDetailedCardType givenBannerId cardTypeId =
                    Gacha.ViewDetailedCardType
                        { bannerId = givenBannerId, cardTypeId = cardTypeId }
                        Api.Start
                        |> wrapGacha

                onClick =
                    { placeholder = viewDetailedCardType
                    , card = viewDetailedCard
                    }
                        |> Just

                filter =
                    filterBy parent.collection.filters parent.gacha.context

                cards =
                    Card.viewCardTypesWithCards onClick filter targetUserId collectionCards.cardTypes
            in
            [ [ User.viewLink User.Full targetUserId user
              , Route.a (Overview |> Route.CardCollection targetUserId) [] [ Html.text "Back to Collection" ]
              ]
            , collectionCards.banner |> Maybe.map viewBanner |> Maybe.withDefault []
            , [ viewFilters parent.gacha.context parent.collection.filters cards.total cards.shown
              , cards.view
              , Card.viewDetailedCardDialog maybeContext parent.gacha
              , Card.viewDetailedCardTypeDialog parent.gacha
              , confirmRecycle
              ]
            ]
                |> List.concat

        pageForCards id _ =
            let
                data =
                    parent.collection.cards
            in
            ( titleFromData id data
            , Api.viewSpecificIdData Api.viewOrError
                viewCollectionCards
                id
                data
            )

        ( title, contents ) =
            case route of
                Overview ->
                    let
                        data =
                            parent.collection.overview
                    in
                    ( titleFromData userId data
                    , Api.viewSpecificIdData Api.viewOrError
                        (viewCollection parent.collection)
                        userId
                        data
                    )

                All ->
                    pageForCards ( userId, Nothing ) Nothing

                Banner bannerId ->
                    pageForCards ( userId, Just bannerId ) Nothing

                Card bannerId cardId ->
                    pageForCards ( userId, Just bannerId ) (Just cardId)

        titleOrDefault =
            title |> Maybe.withDefault "Card Collection"
    in
    { title = titleOrDefault
    , id = "card-collection"
    , body =
        [ [ Html.h2 [] [ Html.text titleOrDefault ] ]
        , contents
        ]
            |> List.concat
    }
