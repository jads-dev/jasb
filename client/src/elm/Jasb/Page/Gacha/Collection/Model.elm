module Jasb.Page.Gacha.Collection.Model exposing
    ( CollectionCards
    , CollectionOverview
    , LocalOrderHighlights
    , ManageContext
    , Model
    , Msg(..)
    , OnClick
    , OrderEditor
    , RecycleProcess(..)
    , allCollectionDecoder
    , bannerCollectionDecoder
    , getHighlights
    , getLocalOrder
    , isOrderChanged
    , localOrderHighlights
    , overviewDecoder
    , removeHighlight
    , reorder
    , replaceOrAddHighlight
    , revertOrder
    )

import AssocList
import DragDrop
import EverySet exposing (EverySet)
import Jasb.Api.Action as Api
import Jasb.Api.Data as Api
import Jasb.Api.IdData as Api
import Jasb.Api.Model as Api
import Jasb.Gacha.Balance as Balance exposing (Balance)
import Jasb.Gacha.Banner as Banner
import Jasb.Gacha.Card as Card
import Jasb.Gacha.CardType as CardType
import Jasb.Gacha.CardType.WithCards as CardType
import Jasb.Page.Gacha.Collection.Filters.Model exposing (..)
import Jasb.User.Model as User
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import List.Extra as List
import Util.AssocList as AssocList
import Util.Json.Decode as JsonD


type RecycleProcess
    = AskConfirmRecycle
    | GetRecycleValue (Api.Response Balance.Value)
    | ExecuteRecycle
    | Recycled (Api.Response Balance)


type Msg
    = LoadCollection User.Id (Api.Response CollectionOverview)
    | LoadCards User.Id (Maybe Banner.Id) (Api.Response CollectionCards)
    | SetEditingHighlights Bool
    | SetCardHighlighted User.Id Banner.Id Card.Id Bool
    | EditHighlightMessage User.Id Banner.Id Card.Id (Maybe String)
    | SetHighlightMessage User.Id Banner.Id Card.Id (Maybe String)
    | HighlightSaved User.Id Banner.Id Card.Id (Api.Response (Maybe Card.Highlighted))
    | ReorderHighlights User.Id (DragDrop.Msg Card.Id Int)
    | SaveHighlightOrder User.Id (List Card.Id) (Maybe (Api.Response Card.Highlights))
    | RecycleCard User.Id Banner.Id Card.Id RecycleProcess
    | CancelRecycle
    | ToggleFilter Filter
    | ShowQualityFilters Bool
    | ShowRarityFilters Bool
    | NoOp String


type LocalOrderHighlights
    = LocalOrderHighlights
        { highlights : Card.Highlights
        , order : List Card.Id
        }


getHighlights : LocalOrderHighlights -> Card.Highlights
getHighlights (LocalOrderHighlights { highlights }) =
    highlights


getLocalOrder : LocalOrderHighlights -> List Card.Id
getLocalOrder (LocalOrderHighlights { order }) =
    order


isOrderChanged : LocalOrderHighlights -> Bool
isOrderChanged (LocalOrderHighlights { order, highlights }) =
    order /= AssocList.keys highlights


reorder : List Card.Id -> LocalOrderHighlights -> LocalOrderHighlights
reorder order (LocalOrderHighlights existing) =
    LocalOrderHighlights { existing | order = order }


revertOrder : LocalOrderHighlights -> LocalOrderHighlights
revertOrder (LocalOrderHighlights highlights) =
    LocalOrderHighlights
        { highlights | order = AssocList.keys highlights.highlights }


localOrderHighlights : Card.Highlights -> LocalOrderHighlights
localOrderHighlights highlights =
    LocalOrderHighlights
        { highlights = highlights, order = highlights |> AssocList.keys }


removeHighlight : Card.Id -> LocalOrderHighlights -> LocalOrderHighlights
removeHighlight id (LocalOrderHighlights { highlights, order }) =
    LocalOrderHighlights
        { highlights = highlights |> AssocList.remove id
        , order = order |> List.remove id
        }


replaceOrAddHighlight : Banner.Id -> Card.Id -> Card.Highlighted -> LocalOrderHighlights -> LocalOrderHighlights
replaceOrAddHighlight bannerId id highlight (LocalOrderHighlights { highlights, order }) =
    if order |> List.member id then
        LocalOrderHighlights
            { highlights = highlights |> AssocList.replace id ( bannerId, highlight )
            , order = order
            }

    else
        LocalOrderHighlights
            { highlights = highlights |> AssocList.insertAtEnd id ( bannerId, highlight )
            , order = order ++ [ id ]
            }


type alias CollectionOverview =
    { user : User.SummaryWithId
    , highlights : LocalOrderHighlights
    , banners : Banner.Banners
    }


overviewDecoder : JsonD.Decoder CollectionOverview
overviewDecoder =
    JsonD.succeed CollectionOverview
        |> JsonD.required "user" User.summaryWithIdDecoder
        |> JsonD.required "highlighted" (Card.highlightsDecoder |> JsonD.map localOrderHighlights)
        |> JsonD.required "banners" Banner.bannersDecoder


type alias CollectionCards =
    { user : User.SummaryWithId
    , banner : Maybe Banner.WithId
    , cardTypes : AssocList.Dict CardType.Id CardType.WithCards
    }


allCollectionDecoder : JsonD.Decoder CollectionCards
allCollectionDecoder =
    let
        cardTypeWithCardsAndBannerDecoder =
            JsonD.field "banner" Banner.idDecoder |> JsonD.andThen CardType.withCardsDecoder

        assocListCardsDecoder =
            JsonD.assocListFromTupleList CardType.idDecoder cardTypeWithCardsAndBannerDecoder
    in
    JsonD.succeed CollectionCards
        |> JsonD.required "user" User.summaryWithIdDecoder
        |> JsonD.hardcoded Nothing
        |> JsonD.required "cards" assocListCardsDecoder


bannerCollectionDecoder : JsonD.Decoder CollectionCards
bannerCollectionDecoder =
    let
        cardsAndBanner withId =
            let
                cardsDecoder =
                    JsonD.assocListFromTupleList CardType.idDecoder
                        (CardType.withCardsDecoder withId.id)
            in
            JsonD.succeed CollectionCards
                |> JsonD.required "user" User.summaryWithIdDecoder
                |> JsonD.hardcoded (Just withId)
                |> JsonD.required "cards" cardsDecoder
    in
    JsonD.field "banner" Banner.withIdDecoder |> JsonD.andThen cardsAndBanner


type alias MessageEditor =
    { card : Card.Id
    , message : String
    }


type alias OrderEditor =
    DragDrop.Model Card.Id Int


type alias RecycleConfirmation =
    { banner : Banner.Id
    , card : Card.Id
    , value : Api.Data Balance.Value
    }


type alias Model =
    { overview : Api.IdData User.Id CollectionOverview
    , cards : Api.IdData ( User.Id, Maybe Banner.Id ) CollectionCards
    , recycleConfirmation : Maybe RecycleConfirmation
    , orderEditor : OrderEditor
    , messageEditor : Maybe MessageEditor
    , saving : Api.ActionState
    , editingHighlights : Bool
    , filters : FilterModel
    }


type alias ManageContext =
    { orderEditor : OrderEditor
    , highlighted : EverySet Card.Id
    }


type alias OnClick msg =
    { placeholder : Banner.Id -> CardType.Id -> msg
    , card : User.Id -> Banner.Id -> Card.Id -> msg
    }
