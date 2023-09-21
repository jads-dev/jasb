module JoeBets.Gacha.Card exposing
    ( Card
    , Cards
    , Detailed
    , DetailedIndividual
    , Highlight
    , Highlighted
    , Highlights
    , Id
    , Individual
    , cardsDecoder
    , cssId
    , decoder
    , detailedDecoder
    , detailedIndividualDecoder
    , encodeId
    , fromDetailed
    , highlightDecoder
    , highlightedDecoder
    , highlightsDecoder
    , idDecoder
    , idFromInt
    , idParser
    , idToInt
    , individualDecoder
    , individualFromDetailed
    , withIdDecoder
    )

import AssocList
import JoeBets.Gacha.Banner as Banner
import JoeBets.Gacha.CardType as CardType exposing (CardType)
import JoeBets.Gacha.Quality as Quality
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


encodeId : Id -> JsonE.Value
encodeId =
    idToInt >> JsonE.int


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
    "card-" ++ (id |> idToInt |> String.fromInt)


{-| The parts of a card unique to that card (i.e: not the card type).
-}
type alias Individual =
    { qualities : Quality.Qualities }


individualDecoder : JsonD.Decoder Individual
individualDecoder =
    JsonD.succeed Individual
        |> JsonD.optional "qualities" Quality.qualitiesDecoder AssocList.empty


type alias Card =
    { cardType : CardType
    , individual : Individual
    }


decoder : JsonD.Decoder Card
decoder =
    JsonD.succeed Card
        |> JsonD.custom CardType.decoder
        |> JsonD.custom individualDecoder


type alias Cards =
    AssocList.Dict Id Card


cardsDecoder : JsonD.Decoder Cards
cardsDecoder =
    JsonD.assocListFromTupleList idDecoder decoder


withIdDecoder : JsonD.Decoder ( Id, Card )
withIdDecoder =
    JsonD.map2 Tuple.pair
        (JsonD.index 0 idDecoder)
        (JsonD.index 1 decoder)


type alias DetailedIndividual =
    { qualities : Quality.DetailedQualities }


individualFromDetailed : DetailedIndividual -> Individual
individualFromDetailed { qualities } =
    Individual (qualities |> Quality.fromDetailedQualities)


detailedIndividualDecoder : JsonD.Decoder DetailedIndividual
detailedIndividualDecoder =
    JsonD.succeed DetailedIndividual
        |> JsonD.optional "qualities" Quality.detailedQualitiesDecoder AssocList.empty


type alias Detailed =
    { cardType : CardType.Detailed
    , individual : DetailedIndividual
    }


detailedDecoder : JsonD.Decoder Detailed
detailedDecoder =
    JsonD.succeed Detailed
        |> JsonD.custom CardType.detailedDecoder
        |> JsonD.custom detailedIndividualDecoder


fromDetailed : Detailed -> Card
fromDetailed { cardType, individual } =
    Card (CardType.fromDetailed cardType) (individualFromDetailed individual)


type alias Highlight =
    { message : Maybe String }


highlightDecoder : JsonD.Decoder Highlight
highlightDecoder =
    JsonD.succeed Highlight
        |> JsonD.optionalAsMaybe "message" JsonD.string


type alias Highlighted =
    { card : Card
    , highlight : Highlight
    }


highlightedDecoder : JsonD.Decoder Highlighted
highlightedDecoder =
    JsonD.succeed Highlighted
        |> JsonD.custom decoder
        |> JsonD.custom highlightDecoder


type alias Highlights =
    AssocList.Dict Id ( Banner.Id, Highlighted )


highlightsDecoder : JsonD.Decoder Highlights
highlightsDecoder =
    let
        fromTuple cardId bannerId highlighted =
            ( cardId, ( bannerId, highlighted ) )

        entryDecoder =
            JsonD.map3 fromTuple
                (JsonD.index 1 idDecoder)
                (JsonD.index 0 Banner.idDecoder)
                (JsonD.index 2 highlightedDecoder)
    in
    JsonD.list entryDecoder |> JsonD.map (List.reverse >> AssocList.fromList)
