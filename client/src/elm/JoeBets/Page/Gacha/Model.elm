module JoeBets.Page.Gacha.Model exposing
    ( CardPointer
    , CardTypePointer
    , EditMsg(..)
    , Model
    , Msg(..)
    )

import DragDrop
import JoeBets.Api.Action as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.IdData as Api
import JoeBets.Api.Model as Api
import JoeBets.Gacha.Balance exposing (Balance)
import JoeBets.Gacha.Banner as Banner
import JoeBets.Gacha.Card as Card
import JoeBets.Gacha.CardType as CardType
import JoeBets.Gacha.Rarity as Rarity
import JoeBets.Page.Gacha.Balance.Model as Balance
import JoeBets.Page.Gacha.Edit.Banner.Model as Banner
import JoeBets.Page.Gacha.Edit.CardType.Model as CardType
import JoeBets.Page.Gacha.Forge.Model as Forge
import JoeBets.Page.Gacha.Roll.Model as Roll
import JoeBets.Page.Gacha.Route exposing (..)
import JoeBets.User.Model as User


type EditMsg
    = EditCardTypes CardType.Msg
    | EditBanners Banner.Msg
    | LoadRarities (Api.Response Rarity.Rarities)


type Msg
    = LoadBalance (Api.Response Balance)
    | LoadBanners (Api.Response Banner.Banners)
    | EditMsg EditMsg
    | ViewDetailedCard CardPointer (Api.Process Card.Detailed)
    | HideDetailedCard
    | ViewDetailedCardType CardTypePointer (Api.Process CardType.Detailed)
    | HideDetailedCardType
    | RollMsg Roll.Msg
    | ForgeMsg Forge.Msg
    | BalanceMsg Balance.Msg
    | CopyImage Card.Id


type alias CardTypePointer =
    { bannerId : Banner.Id
    , cardTypeId : CardType.Id
    }


type alias CardPointer =
    { ownerId : User.Id
    , bannerId : Banner.Id
    , cardId : Card.Id
    }


type alias Model =
    { route : Route
    , balance : Api.Data Balance
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
    , rarityContext : Rarity.Context
    , detailedCard : Api.IdData CardPointer Card.Detailed
    , detailedCardType : Api.IdData CardTypePointer CardType.Detailed
    }
