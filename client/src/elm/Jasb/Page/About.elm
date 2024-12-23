module Jasb.Page.About exposing (view)

import Html
import Html.Attributes as HtmlA
import Jasb.Messages as Global
import Jasb.Page exposing (Page)
import Jasb.Route as Route
import Jasb.Rules as Rules
import Jasb.User.Auth.Controls as Auth
import Jasb.User.Auth.Model as Auth
import Util.Html as Html


type alias Parent a =
    { a | auth : Auth.Model }


view : Parent a -> Page Global.Msg
view { auth } =
    { title = "Joseph Anderson Stream Bets"
    , id = "about"
    , body =
        [ Html.h2 [] [ Html.text "About" ]
        , Html.div []
            [ Html.p []
                [ Html.text "Place bets on Joseph Anderson streams. Bet "
                , Html.text "monocoins on "
                , Route.a Route.Games [] [ Html.text "a variety of bets" ]
                , Html.text " for fun and "
                , Html.text "bragging rights. There is no real-money betting."
                ]
            , Html.p []
                [ Html.text "You need to be "
                , Auth.logInButton auth "logged in"
                , Html.text " with Discord to vote."
                ]
            , Html.p [ HtmlA.class "warning" ]
                [ Html.text "Back-seating in chat to try and achieve your bet is stupid and we will ban you. Don't do it."
                ]
            , Html.p [ HtmlA.class "warning" ]
                [ Html.text "Please be aware that bets may contain spoilers about the games they are for. "
                , Html.text "Major spoilers are hidden by default, but bets will contain smaller details about the game. "
                , Html.text "In general, games Joe has played may be spoiled up to the point he has played (#dragons-den rules). "
                , Html.text "Please don't look at bets for a game you haven't played and care about spoilers for!"
                ]
            , Html.p []
                [ Html.text "When you first log in, you will receive a starting balance, you can bet it on various bets as "
                , Html.text "streams go on. You can always place bets, as the first "
                , Rules.maxStakeWhileInDebt |> String.fromInt |> Html.text
                , Html.text " of each bet will be leveraged (borrowed). At any time you can choose to "
                , Html.text "reset your balance to the starting amount, but you lose all your current bets."
                ]
            , Html.p []
                [ Html.text "JASB has it's own little server where you can get notifications about bets, discuss or suggest bets, or give feedback about the site. "
                , Html.blankA "https://discord.gg" [ "tJjNP4QRvV" ] [ Html.text "Click here or use the invite tJjNP4QRvV to join" ]
                , Html.text "."
                ]
            , Html.p []
                [ Html.text "This is "
                , Html.blankA "https://github.com" [ "jads-dev", "jasb" ] [ Html.text "an open source project" ]
                , Html.text " by "
                , Html.blankA "https://github.com" [ "jads-dev" ] [ Html.text "jads-dev" ]
                , Html.text ". "
                , Html.text "It is an unofficial fan creation."
                ]
            ]
        ]
    }
