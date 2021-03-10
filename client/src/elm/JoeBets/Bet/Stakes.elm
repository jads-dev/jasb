module JoeBets.Bet.Stakes exposing (view)

import AssocList
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Bet.Stake exposing (Stake)
import JoeBets.User.Model as User


view : Maybe User.Id -> Int -> AssocList.Dict User.Id Stake -> Html msg
view localUserId max stakes =
    let
        stakeSegment ( by, { amount } ) =
            let
                stringAmount =
                    amount |> String.fromInt

                local =
                    Just by == localUserId

                titleExtra =
                    if local then
                        " (your bet)"

                    else
                        ""
            in
            Html.span
                [ HtmlA.classList [ ( "local", local ) ]
                , HtmlA.style "flex-grow" stringAmount
                , HtmlA.title (stringAmount ++ titleExtra)
                ]
                []

        total =
            stakes |> AssocList.values |> List.map .amount |> List.sum

        fillerSegment =
            Html.div
                [ HtmlA.classList [ ( "filler", True ) ]
                , HtmlA.style "flex-grow" (max - total |> String.fromInt)
                ]
                []

        barSegments =
            (stakes |> AssocList.toList |> List.map stakeSegment) ++ [ fillerSegment ]
    in
    Html.div [ HtmlA.class "stakes" ] barSegments
