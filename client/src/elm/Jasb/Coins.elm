module Jasb.Coins exposing
    ( view
    , viewAmountOrTransaction
    , viewTransaction
    )

import Html exposing (Html)
import Html.Attributes as HtmlA
import Jasb.Sentiment as Sentiment exposing (Sentiment)

view : Sentiment -> Int -> Html msg
view sentiment amount =
    viewAmountOrTransaction sentiment amount Nothing


viewTransaction : Sentiment -> Int -> Int -> Html msg
viewTransaction sentiment before after =
    viewAmountOrTransaction sentiment before (Just after)


viewAmountOrTransaction : Sentiment -> Int -> Maybe Int -> Html msg
viewAmountOrTransaction sentiment before after =
    let
        rest afterAmount =
            [ Html.text " → ", Sentiment.viewValue sentiment afterAmount ]
    in
    (
      Sentiment.viewValue sentiment before ::
      (after |> Maybe.map rest |> Maybe.withDefault [])
    ) |> Html.span [ HtmlA.class "score" ]
