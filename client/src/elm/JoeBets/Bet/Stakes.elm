module JoeBets.Bet.Stakes exposing (view)

import AssocList
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Keyed as HtmlK
import JoeBets.Bet.Stake as Stake
import JoeBets.Bet.Stake.Model exposing (Stake)
import JoeBets.User.Model as User
import Time.Model as Time


view : Time.Context -> Maybe User.Id -> Maybe User.Id -> Int -> AssocList.Dict User.Id Stake -> Html msg
view timeContext localUserId highlight max stakes =
    let
        stakeSegment ( by, stake ) =
            let
                stringAmount =
                    stake.amount |> String.fromInt

                local =
                    Just by == localUserId
            in
            ( by |> User.idToString
            , Html.span
                [ HtmlA.classList [ ( "local", local ), ( "highlight", Just by == highlight ) ]
                , HtmlA.style "flex-grow" stringAmount
                ]
                [ Stake.view timeContext by stake ]
            )

        total =
            stakes |> AssocList.values |> List.map .amount |> List.sum

        fillerSegment =
            Html.div
                [ HtmlA.classList [ ( "filler", True ) ]
                , HtmlA.style "flex-grow" (max - total |> String.fromInt)
                ]
                []

        barSegments =
            (stakes |> AssocList.toList |> List.map stakeSegment) ++ [ ( "filler", fillerSegment ) ]
    in
    HtmlK.node "div" [ HtmlA.class "stakes" ] barSegments
