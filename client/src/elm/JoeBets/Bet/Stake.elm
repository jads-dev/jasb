module JoeBets.Bet.Stake exposing (view)

import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Bet.Stake.Model exposing (..)
import JoeBets.Coins as Coins
import JoeBets.Route as Route
import JoeBets.User as User
import JoeBets.User.Model as User
import Time.DateTime as DateTime
import Time.Model as Time
import Util.Maybe as Maybe


view : Time.Context -> User.Id -> Stake -> Html msg
view timeContext by { amount, at, user, message } =
    let
        messageIfGiven =
            message |> Maybe.map Html.text |> Maybe.toList
    in
    Html.div [ HtmlA.class "stake" ]
        [ Html.a [ HtmlA.class "user", by |> Just |> Route.User |> Route.toUrl |> HtmlA.href ]
            [ User.viewAvatar user
            , User.viewName user
            ]
        , Coins.view amount
        , Html.span [ HtmlA.class "message" ] messageIfGiven
        , Html.span [ HtmlA.class "at" ] [ DateTime.view timeContext Time.Relative at ]
        ]
