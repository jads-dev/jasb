module JoeBets.Page.About exposing (view)

import Html
import Html.Attributes as HtmlA
import JoeBets.Page exposing (Page)
import JoeBets.Rules as Rules
import JoeBets.User.Auth as Auth
import JoeBets.User.Auth.Model as Auth
import Util.Html as Html


type alias Parent a =
    { a | auth : Auth.Model }


view : (Auth.Msg -> msg) -> Parent a -> Page msg
view wrap { auth } =
    { title = "Joseph Anderson Stream Bets"
    , id = "about"
    , body =
        [ Html.div [ HtmlA.class "about" ]
            [ Html.h2 [] [ Html.text "About" ]
            , Html.p []
                [ Html.text "This site allows you to bet (for bragging rights only, no money!) on various things to do with Joseph Anderson streams. "
                , Html.text "It is an unofficial fan creation."
                ]
            , Html.p []
                [ Html.text "You need to be "
                , Auth.logInButton wrap auth (Html.text "logged in")
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
                , Html.text "streams go on. You can always place bets, but if your balance is negative (or will go "
                , Html.text "negative from the bet) you can only bet a maximum of "
                , Rules.maxStakeWhileInDebt |> String.fromInt |> Html.text
                , Html.text " and you can't place bets on "
                , Html.text "multiple options of the same bet. At any time you can choose to "
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
                , Html.text "."
                ]
            ]
        ]
    }
