module JoeBets.Page.Gacha exposing
    ( init
    , load
    , update
    , view
    )

import DragDrop
import JoeBets.Api as Api
import JoeBets.Api.Action as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.IdData as Api
import JoeBets.Api.Model as Api
import JoeBets.Api.Path as Api
import JoeBets.CopyImage as CopyImage
import JoeBets.Gacha.Card as Card
import JoeBets.Gacha.CardType as CardType
import JoeBets.Gacha.Rarity as Rarity
import JoeBets.Messages as Global
import JoeBets.Page exposing (Page)
import JoeBets.Page.Gacha.Balance as Balance
import JoeBets.Page.Gacha.Collection.Model as Collection
import JoeBets.Page.Gacha.DetailedCard exposing (..)
import JoeBets.Page.Gacha.Edit.Banner exposing (..)
import JoeBets.Page.Gacha.Edit.CardType exposing (..)
import JoeBets.Page.Gacha.Forge as Forge
import JoeBets.Page.Gacha.Forge.Model as Forge
import JoeBets.Page.Gacha.Model exposing (..)
import JoeBets.Page.Gacha.Roll as Roll
import JoeBets.Page.Gacha.Route exposing (..)
import JoeBets.Page.Model as PageModel
import JoeBets.Page.Problem.Model as Problem
import JoeBets.Route as Route
import JoeBets.User.Auth.Model as Auth
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
        , page : PageModel.Page
        , forge : Forge.Model
    }


init : Maybe Route -> Model
init route =
    { route = route |> Maybe.withDefault Roll
    , balance = Api.initData
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
    , rarityContext = { rarities = Api.initData }
    , detailedCard = Api.initIdData
    , detailedCardType = Api.initIdData
    }


loadRarityContext : String -> Rarity.Context -> ( Rarity.Context, Cmd Global.Msg )
loadRarityContext origin context =
    let
        ( rarities, cmd ) =
            { path = Api.Rarities |> Api.Gacha
            , wrap = LoadRarities >> EditMsg >> wrap
            , decoder = Rarity.raritiesDecoder
            }
                |> Api.get origin
                |> Api.getData context.rarities
    in
    ( { context | rarities = rarities }, cmd )


load : Route -> Parent a -> ( Parent a, Cmd Global.Msg )
load route ({ origin, gacha } as model) =
    case model.auth.localUser of
        Just _ ->
            case route of
                Roll ->
                    Roll.load { model | gacha = { gacha | route = route } }

                Forge ->
                    Forge.load { model | gacha = { gacha | route = route } }

                Edit Banner ->
                    loadBannersEditor { model | gacha = { gacha | route = route } }

                Edit (CardType bannerId) ->
                    let
                        ( rarityContext, rarityContextCmd ) =
                            loadRarityContext origin gacha.rarityContext

                        ( updatedModel, cardTypesEditorCmd ) =
                            loadCardTypesEditor bannerId
                                { model
                                    | gacha =
                                        { gacha
                                            | route = route
                                            , rarityContext = rarityContext
                                        }
                                }
                    in
                    ( updatedModel
                    , Cmd.batch [ cardTypesEditorCmd, rarityContextCmd ]
                    )

        Nothing ->
            ( { model
                | problem =
                    Problem.MustBeLoggedIn
                        { path = route |> Route.Gacha |> Route.toUrl }
                , page = PageModel.Problem
              }
            , Cmd.none
            )


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

        EditMsg editMsg ->
            case editMsg of
                EditBanners editBannerMsg ->
                    updateBannersEditor editBannerMsg model

                EditCardTypes editCardTypesMsg ->
                    updateCardTypesEditor editCardTypesMsg model

                LoadRarities response ->
                    let
                        rarityContext context =
                            { context | rarities = context.rarities |> Api.updateData response }
                    in
                    ( { model | gacha = { gacha | rarityContext = rarityContext gacha.rarityContext } }
                    , Cmd.none
                    )

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
                                |> Api.updateIdData pointer response
                    in
                    ( { model | gacha = { gacha | detailedCard = card } }
                    , Cmd.none
                    )

        HideDetailedCard ->
            ( { model | gacha = { gacha | detailedCard = Api.initIdData } }
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
                                |> Api.getIdData pointer gacha.detailedCardType
                    in
                    ( { model | gacha = { gacha | detailedCardType = cardType } }
                    , cmd
                    )

                Api.Finish response ->
                    let
                        cardType =
                            gacha.detailedCardType
                                |> Api.updateIdData pointer response
                    in
                    ( { model | gacha = { gacha | detailedCardType = cardType } }
                    , Cmd.none
                    )

        HideDetailedCardType ->
            ( { model | gacha = { gacha | detailedCardType = Api.initIdData } }
            , Cmd.none
            )

        RollMsg rollMsg ->
            Roll.update rollMsg model

        ForgeMsg forgeMsg ->
            Forge.update forgeMsg model

        BalanceMsg balanceMsg ->
            ( Balance.update balanceMsg model, Cmd.none )

        CopyImage cardId ->
            ( model, cardId |> Card.cssId |> CopyImage.ofId )


view : Parent a -> Page Global.Msg
view ({ gacha } as model) =
    case gacha.route of
        Roll ->
            Roll.view model

        Forge ->
            Forge.view model

        Edit Banner ->
            viewBannersEditor model

        Edit (CardType _) ->
            viewCardTypesEditor model
