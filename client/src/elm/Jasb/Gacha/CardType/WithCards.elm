module Jasb.Gacha.CardType.WithCards exposing
    ( WithCards
    , withCardsDecoder
    )

import AssocList
import Jasb.Gacha.Banner as Banner
import Jasb.Gacha.Card as Card exposing (Card)
import Jasb.Gacha.CardType as CardType exposing (CardType)
import Json.Decode as JsonD
import Util.Json.Decode as JsonD


type alias WithCards =
    { cardType : CardType
    , banner : Banner.Id
    , cards : Card.Cards
    }


withCardsDecoder : Banner.Id -> JsonD.Decoder WithCards
withCardsDecoder banner =
    let
        cardsDecoder cardType =
            JsonD.assocListFromTupleList Card.idDecoder Card.individualDecoder
                |> JsonD.map (expandFromCardType cardType)
                |> JsonD.field "cards"

        expandFromCardType cardType =
            AssocList.map (\_ -> Card cardType) >> WithCards cardType banner
    in
    CardType.decoder |> JsonD.andThen cardsDecoder
