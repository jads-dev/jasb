module Jasb.Bet.Stake exposing (view)

import Html exposing (Html)
import Html.Attributes as HtmlA
import Jasb.Bet.Stake.Model exposing (..)
import Jasb.Coins as Coins
import Jasb.Page.Gacha.Balance as Gacha
import Jasb.Route as Route
import Jasb.Sentiment as Sentiment
import Jasb.User as User
import Jasb.User.Model as User
import Time.DateTime as DateTime
import Time.Model as Time
import Util.Maybe as Maybe


viewPayout : Payout -> Html msg
viewPayout { amount, gacha } =
    [ amount |> Maybe.map (Coins.view Sentiment.PositiveGood)
    , gacha |> Maybe.map (Gacha.viewValue Sentiment.PositiveGood)
    ]
        |> List.filterMap (\item -> item)
        |> List.intersperse (Html.text ", ")
        |> Html.span [ HtmlA.class "payout" ]


view : Time.Context -> User.Id -> Stake -> Html msg
view timeContext by { amount, at, user, message, payout } =
    let
        messageIfGiven =
            message |> Maybe.map Html.text |> Maybe.toList

        value =
            case payout of
                Just givenPayout ->
                    let
                        lost =
                            givenPayout.amount == Nothing

                        ( sentiment, betDescribe ) =
                            if lost then
                                ( Sentiment.PositiveBad, "Lost" )

                            else
                                ( Sentiment.Neutral, "Bet" )

                        payoutDescribe =
                            if lost then
                                "Got"

                            else
                                "Won"
                    in
                    [ Html.text betDescribe
                    , Html.text ": "
                    , Coins.view sentiment amount
                    , Html.text "; "
                    , Html.text payoutDescribe
                    , Html.text ": "
                    , viewPayout givenPayout
                    ]

                Nothing ->
                    [ Coins.view Sentiment.Neutral amount ]
    in
    Html.div [ HtmlA.class "stake" ]
        [ Html.a [ HtmlA.class "user", by |> Just |> Route.User |> Route.toUrl |> HtmlA.href ]
            [ User.viewAvatar user
            , User.viewName user
            ]
        , value |> Html.div [ HtmlA.class "value" ]
        , Html.span [ HtmlA.class "message" ] messageIfGiven
        , Html.span [ HtmlA.class "at" ] [ DateTime.view timeContext Time.Relative at ]
        ]
