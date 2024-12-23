module Jasb.Sentiment exposing
    ( viewValue
    , Sentiment(..)
    )

import Html exposing (Html)
import Html.Attributes as HtmlA

type Sentiment
  = PositiveGood
  | PositiveBad
  | Neutral


viewValue : Sentiment -> Int -> Html msg
viewValue sentiment value =
  let
    (isGood, isBad) =
      case sentiment of
        PositiveGood ->
          (value > 0, value < 0)

        PositiveBad ->
          (value < 0, value > 0)

        Neutral ->
          (False, False)
  in
  Html.span
      [ HtmlA.classList [
        ( "good", isGood ),
        ( "bad", isBad )
      ] ]
      [ value |> String.fromInt |> Html.text ]
