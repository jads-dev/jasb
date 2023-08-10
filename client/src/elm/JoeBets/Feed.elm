module JoeBets.Feed exposing
    ( init
    , load
    , update
    , view
    )

import AssocList
import EverySet
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Events as HtmlE
import JoeBets.Api as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.Path as Api
import JoeBets.Bet.Model as Bet
import JoeBets.Coins as Coins
import JoeBets.Feed.Model exposing (..)
import JoeBets.Game.Id as Game
import JoeBets.Page.Bets.Filters as Filters
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Route as Route
import JoeBets.Settings.Model as Settings
import JoeBets.User as User
import Material.Switch as Switch
import Util.List as List


type alias Parent a =
    { a
        | bets : Bets.Model
        , settings : Settings.Model
        , origin : String
    }


init : Model
init =
    { items = Api.initData
    , favouritesOnly = False
    }


load : (Msg -> msg) -> Maybe ( Game.Id, Bet.Id ) -> Parent a -> Model -> ( Model, Cmd msg )
load wrap limitTo { origin } feed =
    let
        path =
            case limitTo of
                Just ( game, bet ) ->
                    Api.Game game (Api.Bet bet Api.BetFeed)

                Nothing ->
                    Api.Feed

        ( items, cmd ) =
            { path = path
            , wrap = Load >> wrap
            , decoder = decoder
            }
                |> Api.get origin
                |> Api.getData feed.items
    in
    ( { feed | items = items }, cmd )


update : Msg -> Model -> ( Model, Cmd msg )
update msg feed =
    case msg of
        Load result ->
            ( { feed | items = feed.items |> Api.updateData result }
            , Cmd.none
            )

        RevealSpoilers targetIndex ->
            let
                reveal index value =
                    if index == targetIndex then
                        { value | spoilerRevealed = True }

                    else
                        value

                items =
                    feed.items |> Api.mapData (List.indexedMap reveal)
            in
            ( { feed | items = items }
            , Cmd.none
            )

        SetFavouritesOnly favouritesOnly ->
            ( { feed | favouritesOnly = favouritesOnly }, Cmd.none )


view : (Msg -> msg) -> Bool -> Parent a -> Model -> List (Html msg)
view wrap specificFeed { bets, settings } feed =
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

                spoilerAttrs spoiler =
                    if not specificFeed && spoiler && not spoilerRevealed && not (showSpoilersForGame gameId) then
                        ( [ HtmlA.attribute "aria-hidden" "true" ]
                        , [ HtmlA.class "hide-spoilers", RevealSpoilers index |> wrap |> HtmlE.onClick ]
                        )

                    else
                        ( [], [] )

                potentialSpoiler =
                    HtmlA.class "potential-spoiler"

                itemRender isSpoiler icon contents =
                    let
                        ( divAttrs, liAttrs ) =
                            spoilerAttrs isSpoiler
                    in
                    Html.li liAttrs
                        [ Html.div divAttrs contents
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
                        winInfo =
                            if winningBets > 0 then
                                let
                                    eachWon =
                                        if (highlighted.winners |> List.length) > 1 then
                                            " each won "

                                        else
                                            " won "

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
                                in
                                [ highlighted.winners
                                    |> List.map (\{ id, user } -> User.viewLink User.Compact id user)
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
                            [ User.viewLink User.Compact user.id user.user
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
                , Html.label [ HtmlA.class "switch" ]
                    [ Html.span [] [ Html.text "Favourite Games Only" ]
                    , Switch.switch
                        (SetFavouritesOnly >> wrap |> Just)
                        feed.favouritesOnly
                        |> Switch.view
                    ]
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
    prefix ++ Api.viewData Api.viewOrError body feed.items
