module JoeBets.Bet.Option exposing
    ( Id
    , Option
    , decoder
    , encode
    , encodeId
    , idDecoder
    , idFromString
    , idToString
    )

import AssocList
import JoeBets.Bet.Stake.Model as Stake exposing (Stake)
import JoeBets.User.Model as User
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Util.Json.Decode as JsonD


type Id
    = Id String


idToString : Id -> String
idToString (Id string) =
    string


encodeId : Id -> JsonE.Value
encodeId =
    idToString >> JsonE.string


idDecoder : JsonD.Decoder Id
idDecoder =
    JsonD.string |> JsonD.map Id


idFromString : String -> Id
idFromString =
    Id


type alias Option =
    { name : String
    , image : Maybe String
    , stakes : AssocList.Dict User.Id Stake
    }


decoder : JsonD.Decoder Option
decoder =
    JsonD.succeed Option
        |> JsonD.required "name" JsonD.string
        |> JsonD.optionalAsMaybe "image" JsonD.string
        |> JsonD.required "stakes" (JsonD.assocListFromObject User.idFromString Stake.decoder)


encode : Option -> JsonE.Value
encode option =
    [ Just ( "name", option.name |> JsonE.string )
    , option.image |> Maybe.map (\i -> ( "image", i |> JsonE.string ))
    ]
        |> List.filterMap identity
        |> JsonE.object
