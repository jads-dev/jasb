module JoeBets.Page.Gacha.Collection.Model exposing
    ( BannerCollection
    , Collection
    , LocalOrderHighlights
    , ManageContext
    , Model
    , Msg(..)
    , OnClick
    , OrderEditor
    , RecycleProcess(..)
    , bannerCollectionDecoder
    , collectionDecoder
    , getHighlights
    , getLocalOrder
    , isOrderChanged
    , localOrderHighlights
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
import JoeBets.Page.Gacha.Collection.Route exposing (..)
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
    | CancelRecycle
    | Recycled (Api.Response Balance)


type Msg
    = LoadCollection User.Id (Api.Response Collection)
    | LoadBannerCollection User.Id Banner.Id (Api.Response BannerCollection)
    | SetEditingHighlights Bool
    | SetCardHighlighted User.Id Banner.Id Card.Id Bool
    | EditHighlightMessage User.Id Banner.Id Card.Id (Maybe String)
    | SetHighlightMessage User.Id Banner.Id Card.Id (Maybe String)
    | HighlightSaved User.Id Banner.Id Card.Id (Api.Response (Maybe Card.Highlighted))
    | ReorderHighlights User.Id (DragDrop.Msg Card.Id Int)
    | SaveHighlightOrder User.Id (List Card.Id) (Maybe (Api.Response Card.Highlights))
    | RecycleCard User.Id Banner.Id Card.Id RecycleProcess
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


type alias Collection =
    { user : User.SummaryWithId
    , highlights : LocalOrderHighlights
    , banners : Banner.Banners
    }


collectionDecoder : JsonD.Decoder Collection
collectionDecoder =
    JsonD.succeed Collection
        |> JsonD.required "user" User.summaryWithIdDecoder
        |> JsonD.required "highlighted" (Card.highlightsDecoder |> JsonD.map localOrderHighlights)
        |> JsonD.required "banners" Banner.bannersDecoder


type alias BannerCollection =
    { user : User.SummaryWithId
    , banner : Banner.WithId
    , cardTypes : AssocList.Dict CardType.Id CardType.WithCards
    }


bannerCollectionDecoder : JsonD.Decoder BannerCollection
bannerCollectionDecoder =
    JsonD.succeed BannerCollection
        |> JsonD.required "user" User.summaryWithIdDecoder
        |> JsonD.required "banner" Banner.withIdDecoder
        |> JsonD.required "cards" (JsonD.assocListFromTupleList CardType.idDecoder CardType.withCardsDecoder)


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
    { route : Maybe ( User.Id, Route )
    , collection : Api.IdData User.Id Collection
    , bannerCollection : Api.IdData ( User.Id, Banner.Id ) BannerCollection
    , recycleConfirmation : Maybe RecycleConfirmation
    , orderEditor : OrderEditor
    , messageEditor : Maybe MessageEditor
    , saving : Api.ActionState
    , editingHighlights : Bool
    }


type alias ManageContext =
    { orderEditor : OrderEditor
    , highlighted : EverySet Card.Id
    }


type alias OnClick msg =
    { placeholder : Banner.Id -> CardType.Id -> msg
    , card : User.Id -> Banner.Id -> Card.Id -> msg
    }
