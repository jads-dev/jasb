module JoeBets.Page.Bets.Model exposing
    ( GameLockStatus
    , LockBetsMsg(..)
    , LockManager
    , LockStatus
    , Model
    , Msg(..)
    , Selected
    , StoreChange(..)
    , Subset(..)
    , gameLockStatusDecoder
    , lockStatusDecoder
    )

import AssocList
import EverySet exposing (EverySet)
import JoeBets.Api.Action as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.Model as Api
import JoeBets.Bet.Editor.EditableBet exposing (EditableBet)
import JoeBets.Bet.Editor.LockMoment as LockMoment exposing (LockMoment)
import JoeBets.Bet.Model as Bet
import JoeBets.Bet.PlaceBet.Model as PlaceBet
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game
import JoeBets.Page.Bets.Filters exposing (Filter, Filters)
import JoeBets.Store.Item exposing (Item)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Util.Json.Decode as JsonD


type StoreChange
    = FiltersItem Game.Id (Item Filters)
    | FavouritesItem (Item (EverySet Game.Id))


type Subset
    = Active
    | Suggestions


type alias Selected =
    { id : Game.Id
    , subset : Subset
    , data : Api.Data Game.WithBets
    }


type alias LockManager =
    { open : Bool
    , status : Api.Data GameLockStatus
    , action : Api.ActionState
    }


type alias Model =
    { gameBets : Maybe Selected
    , placeBet : PlaceBet.Model
    , filters : AssocList.Dict Game.Id (Item Filters)
    , favourites : Item (EverySet Game.Id)
    , lockManager : LockManager
    }


type alias LockStatus =
    { name : String
    , locked : Bool
    , version : Int
    }


lockStatusDecoder : JsonD.Decoder (AssocList.Dict Bet.Id LockStatus)
lockStatusDecoder =
    let
        lockStatus =
            JsonD.succeed LockStatus
                |> JsonD.required "betName" JsonD.string
                |> JsonD.required "locked" JsonD.bool
                |> JsonD.required "betVersion" JsonD.int
    in
    JsonD.assocListFromList (JsonD.field "betId" Bet.idDecoder) lockStatus


type alias LockMomentStatuses =
    { lockMoment : LockMoment
    , lockStatus : AssocList.Dict Bet.Id LockStatus
    }


lockMomentStatusesDecoder : JsonD.Decoder LockMomentStatuses
lockMomentStatusesDecoder =
    JsonD.map2 LockMomentStatuses
        (JsonD.index 1 LockMoment.decoder)
        (JsonD.index 2 lockStatusDecoder)


type alias GameLockStatus =
    AssocList.Dict LockMoment.Id LockMomentStatuses


gameLockStatusDecoder : JsonD.Decoder GameLockStatus
gameLockStatusDecoder =
    JsonD.assocListFromList (JsonD.index 0 LockMoment.idDecoder) lockMomentStatusesDecoder


type LockBetsMsg
    = Open
    | LockBetsData (Api.Response GameLockStatus)
    | Change Game.Id Bet.Id Int Bool
    | Changed Game.Id Bet.Id (Api.Response EditableBet)
    | Close


type Msg
    = Load Game.Id Subset (Api.Response Game.WithBets)
    | SetFilter Filter Bool
    | ClearFilters
    | SetFavourite Game.Id Bool
    | ReceiveStoreChange StoreChange
    | PlaceBetMsg PlaceBet.Msg
    | Apply (List PlaceBet.Change)
    | LockBets LockBetsMsg
