module JoeBets.Page.Bets.Model exposing
    ( GameBets
    , Model
    , Msg(..)
    , Selected
    , StoreChange(..)
    , Subset(..)
    , gameBetsDecoder
    )

import AssocList
import EverySet exposing (EverySet)
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
    }


type Msg
    = Load Game.Id Subset (RemoteData.Response GameBets)
    | SetFilter Filter Bool
    | ClearFilters
    | SetFavourite Game.Id Bool
    | ReceiveStoreChange StoreChange
    | PlaceBetMsg PlaceBet.Msg
    | Apply (List PlaceBet.Change)
