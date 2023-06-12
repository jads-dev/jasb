module JoeBets.Page.Leaderboard.Model exposing
    ( DebtValue
    , Entries
    , Entry
    , Model
    , Msg(..)
    , NetWorthValue
    , debtEntriesDecoder
    , netWorthEntriesDecoder
    )

import AssocList
import Http
import JoeBets.Page.Leaderboard.Route as Route
import JoeBets.User.Model as User
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Util.Json.Decode as JsonD
import Util.RemoteData exposing (RemoteData)


type alias Entry specific =
    { name : String
    , discriminator : Maybe String
    , avatar : Maybe String
    , avatarCache : Maybe String
    , rank : Int
    , value : specific
    }


type alias NetWorthValue =
    { netWorth : Int }


type alias DebtValue =
    { debt : Int }


entryDecoder : JsonD.Decoder a -> JsonD.Decoder (Entry a)
entryDecoder specificDecoder =
    JsonD.succeed Entry
        |> JsonD.required "name" JsonD.string
        |> JsonD.optionalAsMaybe "discriminator" JsonD.string
        |> JsonD.optionalAsMaybe "avatar" JsonD.string
        |> JsonD.optionalAsMaybe "avatarCache" JsonD.string
        |> JsonD.required "rank" JsonD.int
        |> JsonD.custom specificDecoder


netWorthDecoder : JsonD.Decoder NetWorthValue
netWorthDecoder =
    JsonD.succeed NetWorthValue
        |> JsonD.required "netWorth" JsonD.int


debtDecoder : JsonD.Decoder DebtValue
debtDecoder =
    JsonD.succeed DebtValue
        |> JsonD.required "debt" JsonD.int


type Msg
    = LoadNetWorth (Result Http.Error (AssocList.Dict User.Id (Entry NetWorthValue)))
    | LoadDebt (Result Http.Error (AssocList.Dict User.Id (Entry DebtValue)))


type alias Entries specific =
    RemoteData (AssocList.Dict User.Id (Entry specific))


type alias Model =
    { board : Route.Board
    , netWorth : Entries NetWorthValue
    , debt : Entries DebtValue
    }


entriesDecoder : JsonD.Decoder specific -> JsonD.Decoder (AssocList.Dict User.Id (Entry specific))
entriesDecoder specificDecoder =
    JsonD.assocListFromList
        (JsonD.field "id" User.idDecoder)
        (entryDecoder specificDecoder)


netWorthEntriesDecoder : JsonD.Decoder (AssocList.Dict User.Id (Entry NetWorthValue))
netWorthEntriesDecoder =
    entriesDecoder netWorthDecoder


debtEntriesDecoder : JsonD.Decoder (AssocList.Dict User.Id (Entry DebtValue))
debtEntriesDecoder =
    entriesDecoder debtDecoder
