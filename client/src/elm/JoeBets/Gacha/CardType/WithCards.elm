module JoeBets.Gacha.CardType.WithCards exposing
    ( WithCards
    , withCardsDecoder
    )

import AssocList
import JoeBets.Gacha.Card as Card exposing (Card)
import JoeBets.Gacha.CardType as CardType exposing (CardType)
import Json.Decode as JsonD
import Util.Json.Decode as JsonD


type alias WithCards =
    { cardType : CardType
    , cards : Card.Cards
    }


withCardsDecoder : JsonD.Decoder WithCards
withCardsDecoder =
    let
        cardsDecoder cardType =
            JsonD.assocListFromTupleList Card.idDecoder Card.individualDecoder
                |> JsonD.map (expandFromCardType cardType)
                |> JsonD.field "cards"

        expandFromCardType cardType =
            AssocList.map (\_ -> Card cardType) >> WithCards cardType
    in
    CardType.decoder |> JsonD.andThen cardsDecoder
