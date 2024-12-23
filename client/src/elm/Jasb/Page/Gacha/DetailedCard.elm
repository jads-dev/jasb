module Jasb.Page.Gacha.DetailedCard exposing (viewDetailedCard)

import Jasb.Api as Api
import Jasb.Api.Model as Api
import Jasb.Api.Path as Api
import Jasb.Gacha.Card as Card
import Jasb.Messages as Global
import Jasb.Page.Gacha.Model exposing (..)


viewDetailedCard : String -> CardPointer -> Model -> ( Model, Cmd Global.Msg )
viewDetailedCard origin pointer gacha =
    let
        ( detailedCard, cmd ) =
            { path =
                Api.Card
                    |> Api.SpecificCard pointer.bannerId pointer.cardId
                    |> Api.Cards pointer.ownerId
                    |> Api.Gacha
            , wrap =
                Api.Finish
                    >> ViewDetailedCard pointer
                    >> Global.GachaMsg
            , decoder = Card.detailedDecoder
            }
                |> Api.get origin
                |> showDetailDialog gacha.detailedCard pointer
    in
    ( { gacha | detailedCard = detailedCard }
    , cmd
    )
