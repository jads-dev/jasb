module JoeBets.Page.Bets.Model exposing
    ( GameBets
    , LockBetsMsg(..)
    , LockStatus
    , Model
    , Msg(..)
    , Selected
    , StoreChange(..)
    , Subset(..)
    , gameBetsDecoder
    , lockStatusDecoder
    )

import AssocList
import EverySet exposing (EverySet)
import Http
import JoeBets.Bet.Editor.EditableBet exposing (EditableBet)
import JoeBets.Bet.Model as Bet exposing (Bet)
import JoeBets.Bet.PlaceBet.Model as PlaceBet
import JoeBets.Game.Details as Game
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game
import JoeBets.Page.Bets.Filters exposing (Filter, Filters)
import JoeBets.Store.Item exposing (Item)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Util.Json.Decode as JsonD
import Util.RemoteData as RemoteData exposing (RemoteData)


type StoreChange
    = FiltersItem Game.Id (Item Filters)
    | FavouritesItem (Item (EverySet Game.Id))


type Subset
    = Active
    | Suggestions


type alias GameBets =
    { game : Game.Detailed
    , bets : AssocList.Dict Bet.Id Bet
    }


gameBetsDecoder : JsonD.Decoder GameBets
gameBetsDecoder =
    let
        decoder =
            JsonD.assocListFromList (JsonD.field "id" Bet.idDecoder) (JsonD.field "bet" Bet.decoder)
    in
    JsonD.succeed GameBets
        |> JsonD.required "game" Game.detailedDecoder
        |> JsonD.required "bets" decoder


type alias Selected =
    { id : Game.Id
    , subset : Subset
    , data : RemoteData GameBets
    }


type alias Model =
    { gameBets : Maybe Selected
    , placeBet : PlaceBet.Model
    , filters : AssocList.Dict Game.Id (Item Filters)
    , favourites : Item (EverySet Game.Id)
    , lockStatus : Maybe (RemoteData (AssocList.Dict Bet.Id LockStatus))
    }


type alias LockStatus =
    { name : String
    , locksWhen : String
    , locked : Bool
    , version : Int
    }


lockStatusDecoder : JsonD.Decoder (AssocList.Dict Bet.Id LockStatus)
lockStatusDecoder =
    let
        lockStatus =
            JsonD.succeed LockStatus
                |> JsonD.required "name" JsonD.string
                |> JsonD.required "locksWhen" JsonD.string
                |> JsonD.required "locked" JsonD.bool
                |> JsonD.required "version" JsonD.int
    in
    JsonD.assocListFromList (JsonD.field "id" Bet.idDecoder) lockStatus


type LockBetsMsg
    = Open
    | LockBetsData (RemoteData.Response (AssocList.Dict Bet.Id LockStatus))
    | Change Game.Id Bet.Id Bool
    | Changed Game.Id Bet.Id EditableBet
    | Error Http.Error
    | Close


type Msg
    = Load Game.Id Subset (RemoteData.Response GameBets)
    | SetFilter Filter Bool
    | ClearFilters
    | SetFavourite Game.Id Bool
    | ReceiveStoreChange StoreChange
    | PlaceBetMsg PlaceBet.Msg
    | Apply (List PlaceBet.Change)
    | LockBets LockBetsMsg
