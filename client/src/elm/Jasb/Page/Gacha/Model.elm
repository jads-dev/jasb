module Jasb.Page.Gacha.Model exposing
    ( CardPointer
    , CardTypePointer
    , EditMsg(..)
    , Model
    , Msg(..)
    , closeDetailDialog
    , initDetailDialog
    , showDetailDialog
    , updateDetailDialog
    )

import DragDrop
import Jasb.Api.Action as Api
import Jasb.Api.Data as Api
import Jasb.Api.IdData as Api
import Jasb.Api.Model as Api
import Jasb.Gacha.Balance exposing (Balance)
import Jasb.Gacha.Banner as Banner
import Jasb.Gacha.Card as Card
import Jasb.Gacha.CardType as CardType
import Jasb.Gacha.Context.Model exposing (..)
import Jasb.Page.Gacha.Balance.Model as Balance
import Jasb.Page.Gacha.Edit.Banner.Model as Banner
import Jasb.Page.Gacha.Edit.CardType.Model as CardType
import Jasb.Page.Gacha.Forge.Model as Forge
import Jasb.Page.Gacha.PreviewBanner.Model as PreviewBanner
import Jasb.Page.Gacha.Roll.Model as Roll
import Jasb.User.Model as User


type EditMsg
    = EditCardTypes CardType.Msg
    | EditBanners Banner.Msg


type Msg
    = LoadBalance (Api.Response Balance)
    | LoadBanners (Api.Response Banner.Banners)
    | LoadContext (Api.Response InnerContext)
    | EditMsg EditMsg
    | ViewDetailedCard CardPointer (Api.Process Card.Detailed)
    | HideDetailedCard
    | ViewDetailedCardType CardTypePointer (Api.Process CardType.Detailed)
    | HideDetailedCardType
    | LoadBannerPreview Banner.Id (Api.Response PreviewBanner.Model)
    | RollMsg Roll.Msg
    | ForgeMsg Forge.Msg
    | BalanceMsg Balance.Msg


type alias CardTypePointer =
    { bannerId : Banner.Id
    , cardTypeId : CardType.Id
    }


type alias CardPointer =
    { ownerId : User.Id
    , bannerId : Banner.Id
    , cardId : Card.Id
    }


type alias DetailDialog pointer detail =
    { open : Bool
    , detail : Api.IdData pointer detail
    }


initDetailDialog : DetailDialog pointer detail
initDetailDialog =
    { open = False, detail = Api.initIdData }


showDetailDialog : DetailDialog pointer detail -> pointer -> Cmd msg -> ( DetailDialog pointer detail, Cmd msg )
showDetailDialog dialog pointer getDetail =
    let
        ( detail, cmd ) =
            getDetail |> Api.getIdData pointer dialog.detail
    in
    ( { dialog | open = True, detail = detail }, cmd )


updateDetailDialog : pointer -> Api.Response detail -> DetailDialog pointer detail -> DetailDialog pointer detail
updateDetailDialog pointer response dialog =
    { dialog | detail = dialog.detail |> Api.updateIdData pointer response }


closeDetailDialog : DetailDialog pointer detail -> DetailDialog pointer detail
closeDetailDialog dialog =
    { dialog | open = False }


type alias Model =
    { balance : Api.Data Balance
    , balanceInfoShown : Bool
    , banners : Api.Data Banner.Banners
    , rollAction : Api.ActionState
    , roll : Maybe Roll.Model
    , editableBanners : Api.Data Banner.EditableBanners
    , bannerEditor : Maybe Banner.Editor
    , bannerOrderDragDrop : DragDrop.Model Banner.Id Int
    , saveBannerOrder : Api.ActionState
    , editableCardTypes : Api.IdData Banner.Id CardType.EditableCardTypes
    , cardTypeEditor : Maybe CardType.Editor
    , context : Context
    , detailedCard : DetailDialog CardPointer Card.Detailed
    , detailedCardType : DetailDialog CardTypePointer CardType.Detailed
    , bannerPreview : Api.IdData Banner.Id PreviewBanner.Model
    }
