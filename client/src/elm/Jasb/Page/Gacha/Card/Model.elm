module Jasb.Page.Gacha.Card.Model exposing
    ( CardFilter
    , CardTypeFilter
    , Filter
    , FilteredView
    )

import Jasb.Gacha.Card as Card exposing (Card)
import Jasb.Gacha.CardType as CardType
import Jasb.Gacha.CardType.WithCards as CardType


type alias CardFilter =
    Card.Id -> Card -> Bool


type alias CardTypeFilter =
    CardType.Id -> CardType.WithCards -> Bool


type alias Filter =
    { card : CardFilter
    , cardType : CardTypeFilter
    }


type alias FilteredView view =
    { view : view
    , total : Int
    , shown : Int
    }
