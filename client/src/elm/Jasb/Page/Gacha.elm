module Jasb.Page.Gacha exposing
    ( init
    , load
    , onAuthChange
    , update
    , view
    )

import DragDrop
import Jasb.Api as Api
import Jasb.Api.Action as Api
import Jasb.Api.Data as Api
import Jasb.Api.IdData as Api
import Jasb.Api.Model as Api
import Jasb.Api.Path as Api
import Jasb.Gacha.CardType as CardType
import Jasb.Gacha.Context exposing (..)
import Jasb.Messages as Global
import Jasb.Page exposing (Page)
import Jasb.Page.Gacha.Balance as Balance
import Jasb.Page.Gacha.Collection.Model as Collection
import Jasb.Page.Gacha.DetailedCard exposing (..)
import Jasb.Page.Gacha.Edit.Banner exposing (..)
import Jasb.Page.Gacha.Edit.CardType exposing (..)
import Jasb.Page.Gacha.Forge as Forge
import Jasb.Page.Gacha.Forge.Model as Forge
import Jasb.Page.Gacha.Model exposing (..)
import Jasb.Page.Gacha.PreviewBanner as PreviewBanner
import Jasb.Page.Gacha.Roll as Roll
import Jasb.Page.Gacha.Route exposing (..)
import Jasb.Page.Problem.Model as Problem
import Jasb.Route as Route
import Jasb.User.Auth.Controls as Auth
import Jasb.User.Auth.Model as Auth
import Time.Model as Time


wrap : Msg -> Global.Msg
wrap =
    Global.GachaMsg


type alias Parent a =
    { a
        | origin : String
        , time : Time.Context
        , auth : Auth.Model
        , gacha : Model
        , collection : Collection.Model
        , problem : Problem.Model
        , route : Route.Route
        , forge : Forge.Model
    }


init : Model
init =
    { balance = Api.initData
    , balanceInfoShown = False
    , banners = Api.initData
    , rollAction = Api.initAction
    , roll = Nothing
    , editableBanners = Api.initData
    , bannerEditor = Nothing
    , bannerOrderDragDrop = DragDrop.init
    , saveBannerOrder = Api.initAction
    , editableCardTypes = Api.initIdData
    , cardTypeEditor = Nothing
    , context = Api.initData
    , detailedCard = initDetailDialog
    , detailedCardType = initDetailDialog
    , bannerPreview = Api.initIdData
    }


loadEdit : EditTarget -> Parent a -> ( Parent a, Cmd Global.Msg )
loadEdit editTarget ({ origin, gacha } as model) =
    case model.auth.localUser of
        Just _ ->
            case editTarget of
                Banner ->
                    loadBannersEditor model

                CardType bannerId ->
                    let
                        ( context, contextCmd ) =
                            loadContextIfNeeded origin gacha.context

                        ( updatedModel, cardTypesEditorCmd ) =
                            loadCardTypesEditor bannerId
                                { model | gacha = { gacha | context = context } }
                    in
                    ( updatedModel
                    , Cmd.batch [ cardTypesEditorCmd, contextCmd ]
                    )

        Nothing ->
            ( Auth.mustBeLoggedIn (editTarget |> Edit |> Route.Gacha) model
            , Cmd.none
            )


onAuthChange : Route -> Parent a -> ( Parent a, Cmd Global.Msg )
onAuthChange route parent =
    case route of
        Roll ->
            Roll.onAuthChange parent

        Forge ->
            Forge.onAuthChange parent

        Edit editTarget ->
            loadEdit editTarget parent

        _ ->
            ( parent, Cmd.none )


load : Route -> Parent a -> ( Parent a, Cmd Global.Msg )
load route model =
    case route of
        Roll ->
            Roll.load model

        Forge ->
            Forge.load model

        PreviewBanner bannerId ->
            PreviewBanner.load bannerId model

        Edit editTarget ->
            loadEdit editTarget model


update : Msg -> Parent a -> ( Parent a, Cmd Global.Msg )
update msg ({ origin, gacha } as model) =
    case msg of
        LoadBalance response ->
            ( { model | gacha = { gacha | balance = gacha.balance |> Api.updateData response } }
            , Cmd.none
            )

        LoadBanners response ->
            ( { model | gacha = { gacha | banners = gacha.banners |> Api.updateData response } }
            , Cmd.none
            )

        LoadContext response ->
            ( { model | gacha = { gacha | context = gacha.context |> Api.updateData response } }
            , Cmd.none
            )

        EditMsg editMsg ->
            case editMsg of
                EditBanners editBannerMsg ->
                    updateBannersEditor editBannerMsg model

                EditCardTypes editCardTypesMsg ->
                    updateCardTypesEditor editCardTypesMsg model

        ViewDetailedCard pointer process ->
            case process of
                Api.Start ->
                    let
                        ( newGacha, cmd ) =
                            viewDetailedCard origin pointer gacha
                    in
                    ( { model | gacha = newGacha }
                    , cmd
                    )

                Api.Finish response ->
                    let
                        card =
                            gacha.detailedCard
                                |> updateDetailDialog pointer response
                    in
                    ( { model | gacha = { gacha | detailedCard = card } }
                    , Cmd.none
                    )

        HideDetailedCard ->
            ( { model | gacha = { gacha | detailedCard = closeDetailDialog gacha.detailedCard } }
            , Cmd.none
            )

        ViewDetailedCardType pointer process ->
            case process of
                Api.Start ->
                    let
                        ( cardType, cmd ) =
                            { path =
                                Api.DetailedCardType pointer.cardTypeId
                                    |> Api.SpecificBanner pointer.bannerId
                                    |> Api.Banners
                                    |> Api.Gacha
                            , wrap =
                                Api.Finish
                                    >> ViewDetailedCardType pointer
                                    >> wrap
                            , decoder = CardType.detailedDecoder
                            }
                                |> Api.get origin
                                |> showDetailDialog gacha.detailedCardType pointer
                    in
                    ( { model | gacha = { gacha | detailedCardType = cardType } }
                    , cmd
                    )

                Api.Finish response ->
                    let
                        cardType =
                            gacha.detailedCardType
                                |> updateDetailDialog pointer response
                    in
                    ( { model | gacha = { gacha | detailedCardType = cardType } }
                    , Cmd.none
                    )

        HideDetailedCardType ->
            ( { model | gacha = { gacha | detailedCardType = closeDetailDialog gacha.detailedCardType } }
            , Cmd.none
            )

        LoadBannerPreview bannerId response ->
            let
                bannerPreview =
                    gacha.bannerPreview |> Api.updateIdData bannerId response
            in
            ( { model | gacha = { gacha | bannerPreview = bannerPreview } }
            , Cmd.none
            )

        RollMsg rollMsg ->
            Roll.update rollMsg model

        ForgeMsg forgeMsg ->
            Forge.update forgeMsg model

        BalanceMsg balanceMsg ->
            ( Balance.update balanceMsg model, Cmd.none )


view : Route -> Parent a -> Page Global.Msg
view route model =
    case route of
        Roll ->
            Roll.view model

        Forge ->
            Forge.view model

        PreviewBanner bannerId ->
            PreviewBanner.view bannerId model

        Edit Banner ->
            viewBannersEditor model

        Edit (CardType _) ->
            viewCardTypesEditor model
