module JoeBets.Page.Gacha.Collection.Model exposing
    ( AllCollection
    , BannerCollection
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
import JoeBets.Api.Action as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.IdData as Api
import JoeBets.Api.Model as Api
import JoeBets.Gacha.Balance as Balance exposing (Balance)
import JoeBets.Gacha.Banner as Banner
import JoeBets.Gacha.Card as Card
import JoeBets.Gacha.CardType as CardType
import JoeBets.Gacha.CardType.WithCards as CardType
import JoeBets.Page.Gacha.Collection.Filters.Model exposing (..)
import JoeBets.User.Model as User
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
    | LoadAllCards User.Id (Api.Response AllCollection)
    | LoadBannerCollection User.Id Banner.Id (Api.Response BannerCollection)
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


type alias AllCollection =
    { user : User.SummaryWithId
    , cardTypes : AssocList.Dict CardType.Id CardType.WithCards
    }


allCollectionDecoder : JsonD.Decoder AllCollection
allCollectionDecoder =
    let
        cardTypeWithCardsAndBannerDecoder =
            JsonD.field "banner" Banner.idDecoder |> JsonD.andThen CardType.withCardsDecoder

        assocListCardsDecoder =
            JsonD.assocListFromTupleList CardType.idDecoder cardTypeWithCardsAndBannerDecoder
    in
    JsonD.succeed AllCollection
        |> JsonD.required "user" User.summaryWithIdDecoder
        |> JsonD.required "cards" assocListCardsDecoder


type alias BannerCollection =
    { user : User.SummaryWithId
    , banner : Banner.WithId
    , cardTypes : AssocList.Dict CardType.Id CardType.WithCards
    }


bannerCollectionDecoder : JsonD.Decoder BannerCollection
bannerCollectionDecoder =
    let
        cardsAndBanner ( bannerId, banner ) =
            let
                cardsDecoder =
                    JsonD.assocListFromTupleList CardType.idDecoder
                        (CardType.withCardsDecoder bannerId)
            in
            JsonD.succeed BannerCollection
                |> JsonD.required "user" User.summaryWithIdDecoder
                |> JsonD.hardcoded ( bannerId, banner )
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
    , allCollection : Api.IdData User.Id AllCollection
    , bannerCollection : Api.IdData ( User.Id, Banner.Id ) BannerCollection
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
