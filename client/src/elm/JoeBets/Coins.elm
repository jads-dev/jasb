module JoeBets.Coins exposing
    ( view
    , viewAmountOrTransaction
    , viewTransaction
    )

import Html exposing (Html)
import Html.Attributes as HtmlA


view : Int -> Html msg
view amount =
    viewAmountOrTransaction amount Nothing


viewTransaction : Int -> Int -> Html msg
viewTransaction before after =
    viewAmountOrTransaction before (Just after)


viewAmountOrTransaction : Int -> Maybe Int -> Html msg
viewAmountOrTransaction before after =
    let
        goodBad score =
            Html.span
                [ HtmlA.classList [ ( "good", score > 0 ), ( "bad", score < 0 ) ] ]
                [ score |> String.fromInt |> Html.text ]

        rest afterAmount =
            [ Html.text " → ", goodBad afterAmount ]
    in
    Html.span [ HtmlA.class "score" ] (goodBad before :: (after |> Maybe.map rest |> Maybe.withDefault []))
