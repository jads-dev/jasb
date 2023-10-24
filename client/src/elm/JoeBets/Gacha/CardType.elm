module JoeBets.Gacha.CardType exposing
    ( CardType
    , CardTypes
    , Detailed
    , EditableCardType
    , EditableCardTypes
    , Id
    , WithId
    , cardTypesDecoder
    , cssId
    , decoder
    , detailedDecoder
    , editableCardTypesDecoder
    , editableDecoder
    , editableWithIdDecoder
    , fromDetailed
    , idDecoder
    , idFromInt
    , idParser
    , idToInt
    , withIdDecoder
    )

import AssocList
import JoeBets.Gacha.Banner as Banner
import JoeBets.Gacha.Card.Layout as Card
import JoeBets.Gacha.Credits as Credits
import JoeBets.Gacha.Rarity as Rarity
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Time.DateTime as DateTime exposing (DateTime)
import Url.Parser as Url
import Util.Json.Decode as JsonD


type Id
    = Id Int


idToInt : Id -> Int
idToInt (Id int) =
    int


idParser : Url.Parser (Id -> a) a
idParser =
    Url.custom "CARD TYPE ID" (String.toInt >> Maybe.map Id)


idDecoder : JsonD.Decoder Id
idDecoder =
    JsonD.int |> JsonD.map Id


idFromInt : Int -> Id
idFromInt =
    Id


cssId : Id -> String
cssId id =
    "card-type-" ++ (id |> idToInt |> String.fromInt)


type alias CardType =
    { name : String
    , description : String
    , image : String
    , rarity : Rarity.WithId
    , layout : Card.Layout
    , retired : Bool
    }


decoder : JsonD.Decoder CardType
decoder =
    JsonD.succeed CardType
        |> JsonD.required "name" JsonD.string
        |> JsonD.required "description" JsonD.string
        |> JsonD.required "image" JsonD.string
        |> JsonD.required "rarity" Rarity.withIdDecoder
        |> JsonD.required "layout" Card.layoutDecoder
        |> JsonD.optional "retired" JsonD.bool False


type alias WithId =
    { id : Id, cardType : CardType }


withIdDecoder : JsonD.Decoder WithId
withIdDecoder =
    JsonD.map2 WithId
        (JsonD.index 0 idDecoder)
        (JsonD.index 1 decoder)


type alias Detailed =
    { cardType : CardType
    , banner : Banner.WithId
    , credits : List Credits.Credit
    }


detailedDecoder : JsonD.Decoder Detailed
detailedDecoder =
    JsonD.succeed Detailed
        |> JsonD.custom decoder
        |> JsonD.required "banner" Banner.withIdDecoder
        |> JsonD.required "credits" (JsonD.list Credits.decoder)


fromDetailed : Detailed -> CardType
fromDetailed =
    .cardType


type alias CardTypes =
    AssocList.Dict Id CardType


cardTypesDecoder : JsonD.Decoder CardTypes
cardTypesDecoder =
    JsonD.assocListFromTupleList idDecoder decoder


type alias EditableCardType =
    { name : String
    , description : String
    , image : String
    , retired : Bool
    , rarity : Rarity.Id
    , layout : Card.Layout
    , credits : Credits.EditableCredits

    -- Metadata
    , version : Int
    , created : DateTime
    , modified : DateTime
    }


editableDecoder : JsonD.Decoder EditableCardType
editableDecoder =
    JsonD.succeed EditableCardType
        |> JsonD.required "name" JsonD.string
        |> JsonD.required "description" JsonD.string
        |> JsonD.required "image" JsonD.string
        |> JsonD.required "retired" JsonD.bool
        |> JsonD.required "rarity" Rarity.idDecoder
        |> JsonD.required "layout" Card.layoutDecoder
        |> JsonD.required "credits" Credits.editablesDecoder
        |> JsonD.required "version" JsonD.int
        |> JsonD.required "created" DateTime.decoder
        |> JsonD.required "modified" DateTime.decoder


editableWithIdDecoder : JsonD.Decoder ( Id, EditableCardType )
editableWithIdDecoder =
    JsonD.map2 Tuple.pair
        (JsonD.index 0 idDecoder)
        (JsonD.index 1 editableDecoder)


type alias EditableCardTypes =
    AssocList.Dict Id EditableCardType


editableCardTypesDecoder : JsonD.Decoder EditableCardTypes
editableCardTypesDecoder =
    JsonD.assocListFromTupleList idDecoder editableDecoder
