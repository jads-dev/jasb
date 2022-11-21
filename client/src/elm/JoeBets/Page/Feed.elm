module JoeBets.Page.Feed exposing
    ( init
    , load
    , update
    , view
    )

import AssocList
import EverySet
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html
import Html.Attributes as HtmlA
import Html.Events as HtmlE
import Http
import JoeBets.Api as Api
import JoeBets.Bet.Model as Bet
import JoeBets.Coins as Coins
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game
import JoeBets.Page exposing (Page)
import JoeBets.Page.Bets.Filters as Filters
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Page.Feed.Model exposing (..)
import JoeBets.Route as Route
import JoeBets.Settings.Model as Settings
import JoeBets.User as User
import Material.Switch as Switch
import Util.List as List
import Util.RemoteData as RemoteData


type alias Parent a =
    { a
        | feed : Model
        , bets : Bets.Model
        , settings : Settings.Model
        , origin : String
    }


init : Model
init =
    { items = RemoteData.Missing
    , favouritesOnly = False
    }


load : (Msg -> msg) -> Maybe ( Game.Id, Bet.Id ) -> Parent a -> ( Parent a, Cmd msg )
load wrap limitTo ({ origin } as model) =
    let
        path =
            case limitTo of
                Just ( game, bet ) ->
                    Api.Game game (Api.Bet bet Api.BetFeed)

                Nothing ->
                    Api.Feed
    in
    ( model
    , Api.get origin
        { path = path
        , expect = Http.expectJson (Load >> wrap) decoder
        }
    )


update : (Msg -> msg) -> Msg -> Parent a -> ( Parent a, Cmd msg )
update _ msg ({ feed } as model) =
    case msg of
        Load result ->
            let
                newItems =
                    case result of
                        Ok items ->
                            RemoteData.Loaded items

                        Err error ->
                            RemoteData.Failed error
            in
            ( { model | feed = { feed | items = newItems } }, Cmd.none )

        RevealSpoilers targetIndex ->
            let
                reveal index value =
                    if index == targetIndex then
                        { value | spoilerRevealed = True }

                    else
                        value
            in
            ( { model | feed = { feed | items = feed.items |> RemoteData.map (List.indexedMap reveal) } }, Cmd.none )

        SetFavouritesOnly favouritesOnly ->
            ( { model | feed = { feed | favouritesOnly = favouritesOnly } }, Cmd.none )


view : (Msg -> msg) -> Bool -> Parent a -> Page msg
view wrap specificFeed { feed, bets, settings } =
    let
        showSpoilersForGame id =
            let
                gameFilters =
                    bets.filters
                        |> AssocList.get id
                        |> Maybe.map .value
                        |> Maybe.withDefault Filters.init
            in
            settings.defaultFilters.value
                |> Filters.merge gameFilters
                |> Filters.resolveDefaults
                |> .spoilers

        viewItem { index, event, spoilerRevealed } =
            let
                gameId =
                    case event of
                        NB { game } ->
                            game.id

                        BC { game } ->
                            game.id

                        NS { game } ->
                            game.id

                spoilerAttr spoiler =
                    if not specificFeed && spoiler && not spoilerRevealed && not (showSpoilersForGame gameId) then
                        [ HtmlA.class "hide-spoilers", RevealSpoilers index |> wrap |> HtmlE.onClick ]

                    else
                        []

                potentialSpoiler =
                    HtmlA.class "potential-spoiler"

                viewUser user =
                    Route.a (user.id |> Just |> Route.User)
                        [ HtmlA.class "user permalink" ]
                        [ User.viewAvatar user.id user
                        , Html.span [ HtmlA.class "name" ] [ Html.text user.name ]
                        ]

                itemRender isSpoiler icon contents =
                    Html.li (spoilerAttr isSpoiler)
                        [ Html.div [] contents
                        , icon |> Icon.view
                        ]
            in
            case event of
                NB { game, bet, spoiler } ->
                    itemRender spoiler
                        Icon.plusCircle
                        [ Html.p []
                            [ Html.text "New bet available on “"
                            , Route.a (Route.Bets Bets.Active game.id) [] [ Html.text game.name ]
                            , Html.text "”: “"
                            , Route.a (Route.Bet game.id bet.id) [ potentialSpoiler ] [ Html.text bet.name ]
                            , Html.text "”."
                            ]
                        ]

                BC { game, bet, spoiler, winners, highlighted, totalReturn, winningBets } ->
                    let
                        otherWinnerCount =
                            winningBets - (highlighted.winners |> List.length)

                        others =
                            if otherWinnerCount > 0 then
                                [ Html.text " They and "
                                , otherWinnerCount |> String.fromInt |> Html.text
                                , Html.text " others share a total of "
                                , totalReturn |> Coins.view
                                , Html.text " in winnings."
                                ]

                            else if (highlighted.winners |> List.length) > 1 then
                                [ Html.text " A total of ", totalReturn |> Coins.view ]

                            else
                                []

                        eachWon =
                            if (highlighted.winners |> List.length) > 1 then
                                " each won "

                            else
                                " won "

                        winInfo =
                            if winningBets > 0 then
                                [ highlighted.winners
                                    |> List.map viewUser
                                    |> List.intersperse (Html.text ", ")
                                    |> List.addBeforeLast (Html.text "and ")
                                , [ Html.text eachWon
                                  , highlighted.amount |> Coins.view
                                  , Html.text "!"
                                  ]
                                , others
                                ]

                            else
                                [ [ Html.text "No one bet on that option!" ] ]

                        winnersText =
                            winners
                                |> List.map (\w -> "“" ++ w.name ++ "”" |> Html.text)
                                |> List.intersperse (Html.text ", ")
                                |> List.addBeforeLast (Html.text "and ")
                    in
                    itemRender spoiler
                        Icon.checkCircle
                        [ Html.p []
                            [ Html.text "The bet “"
                            , Route.a (Route.Bet game.id bet.id) [ potentialSpoiler ] [ Html.text bet.name ]
                            , Html.text "” for the game “"
                            , Route.a (Route.Bets Bets.Active game.id) [] [ Html.text game.name ]
                            , Html.text "” has been resolved! "
                            , Html.span [ potentialSpoiler ] winnersText
                            , Html.text " won."
                            ]
                        , winInfo |> List.concat |> Html.p []
                        ]

                NS { game, bet, spoiler, option, user, message, stake } ->
                    itemRender spoiler
                        Icon.exclamationCircle
                        [ Html.p []
                            [ Html.text "Big bet of "
                            , stake |> Coins.view
                            , Html.text " on “"
                            , Html.span [ potentialSpoiler ] [ Html.text option.name ]
                            , Html.text "” in the bet “"
                            , Route.a (Route.Bet game.id bet.id) [ potentialSpoiler ] [ Html.text bet.name ]
                            , Html.text "” for the game “"
                            , Route.a (Route.Bets Bets.Active game.id) [] [ Html.text game.name ]
                            , Html.text "”."
                            ]
                        , Html.div [ HtmlA.class "message" ]
                            [ viewUser user
                            , Html.q [ potentialSpoiler ] [ Html.text message ]
                            ]
                        ]

        prefix =
            if specificFeed then
                []

            else
                [ Html.h2 [] [ Html.text "Feed" ]
                , Html.p []
                    [ Html.text "Potential spoilers may be blurred if you have spoilers hidden for the game. "
                    , Html.text "Click on the item to reveal spoilers in it."
                    ]
                , Switch.view (Html.text "Favourite Games Only")
                    feed.favouritesOnly
                    (SetFavouritesOnly >> wrap |> Just)
                ]

        body items =
            let
                showItem game =
                    EverySet.member game bets.favourites.value

                filteredItems =
                    if not specificFeed && feed.favouritesOnly then
                        items |> List.filter (.event >> relevantGame >> Maybe.map showItem >> Maybe.withDefault True)

                    else
                        items
            in
            if filteredItems |> List.isEmpty then
                [ Html.p [] [ Html.text "No activity yet." ] ]

            else
                [ filteredItems |> List.map viewItem |> Html.ol [] ]
    in
    { title = "Feed"
    , id = "feed"
    , body = prefix ++ RemoteData.view body feed.items
    }
