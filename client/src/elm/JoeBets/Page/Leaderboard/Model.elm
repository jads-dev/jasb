module JoeBets.Page.Leaderboard.Model exposing
    ( Entry
    , Model
    , Msg(..)
    , decoder
    , entryDecoder
    )

import AssocList
import Http
import JoeBets.User.Model as User
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Util.Json.Decode as JsonD
import Util.RemoteData exposing (RemoteData)


type alias Entry =
    { name : String
    , discriminator : String
    , avatar : Maybe String
    , rank : Int
    , netWorth : Int
    }


entryDecoder : JsonD.Decoder Entry
entryDecoder =
    JsonD.succeed Entry
        |> JsonD.required "name" JsonD.string
        |> JsonD.required "discriminator" JsonD.string
        |> JsonD.optional "avatar" (JsonD.string |> JsonD.map Just) Nothing
        |> JsonD.required "rank" JsonD.int
        |> JsonD.required "netWorth" JsonD.int


type Msg
    = Load (Result Http.Error (AssocList.Dict User.Id Entry))


type alias Model =
    RemoteData (AssocList.Dict User.Id Entry)


decoder : JsonD.Decoder (AssocList.Dict User.Id Entry)
decoder =
    JsonD.assocListFromList (JsonD.field "id" User.idDecoder) entryDecoder
