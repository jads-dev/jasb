module Jasb.Gacha.Credits exposing
    ( Credit
    , CreditLike
    , EditableCredit
    , EditableCredits
    , Id
    , UserOrName(..)
    , decoder
    , editableDecoder
    , editablesDecoder
    , encodeId
    , idDecoder
    , idFromInt
    , idParser
    , idToInt
    , userOrName
    )

import AssocList
import Jasb.User.Model as User
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Url.Parser as Url
import Util.Json.Decode as JsonD


type Id
    = Id Int


idToInt : Id -> Int
idToInt (Id int) =
    int


idParser : Url.Parser (Id -> a) a
idParser =
    Url.custom "CREDIT ID" (String.toInt >> Maybe.map Id)


idDecoder : JsonD.Decoder Id
idDecoder =
    JsonD.int |> JsonD.map Id


idFromInt : Int -> Id
idFromInt =
    Id


encodeId : Id -> JsonE.Value
encodeId =
    idToInt >> JsonE.int


type alias CreditLike a =
    { a
        | reason : String
        , id : Maybe User.Id
        , name : String
        , discriminator : Maybe String
        , avatar : Maybe String
    }


type alias Credit =
    { reason : String
    , id : Maybe User.Id
    , name : String
    , discriminator : Maybe String
    , avatar : Maybe String
    }


decoder : JsonD.Decoder Credit
decoder =
    JsonD.succeed Credit
        |> JsonD.required "reason" JsonD.string
        |> JsonD.optionalAsMaybe "id" User.idDecoder
        |> JsonD.required "name" JsonD.string
        |> JsonD.optionalAsMaybe "discriminator" JsonD.string
        |> JsonD.optionalAsMaybe "avatar" JsonD.string


type alias EditableCredit =
    { reason : String
    , id : Maybe User.Id
    , name : String
    , discriminator : Maybe String
    , avatar : Maybe String
    , version : Int
    }


editableDecoder : JsonD.Decoder EditableCredit
editableDecoder =
    JsonD.succeed EditableCredit
        |> JsonD.required "reason" JsonD.string
        |> JsonD.optionalAsMaybe "id" User.idDecoder
        |> JsonD.required "name" JsonD.string
        |> JsonD.optionalAsMaybe "discriminator" JsonD.string
        |> JsonD.optionalAsMaybe "avatar" JsonD.string
        |> JsonD.required "version" JsonD.int


type alias EditableCredits =
    AssocList.Dict Id EditableCredit


editablesDecoder : JsonD.Decoder EditableCredits
editablesDecoder =
    JsonD.assocListFromTupleList idDecoder editableDecoder


type UserOrName
    = Name String
    | User User.SummaryWithId


userOrName : CreditLike a -> UserOrName
userOrName { id, name, discriminator, avatar } =
    let
        fromIdAndAvatar givenId givenAvatar =
            User.Summary name discriminator givenAvatar
                |> User.SummaryWithId givenId
    in
    case Maybe.map2 fromIdAndAvatar id avatar of
        Just summaryWithId ->
            User summaryWithId

        Nothing ->
            Name name
