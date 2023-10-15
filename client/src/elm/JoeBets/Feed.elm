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
import JoeBets.Filtering as Filtering
import JoeBets.Game.Id as Game
import JoeBets.Page.Bets.Filters as Filters
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Route as Route
import JoeBets.Settings.Model as Settings
import JoeBets.User as User
import Material.Chips.Filter as FilterChip
import Util.EverySet as EverySet
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
    , filters = defaultFilters
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

        ToggleFilter filter ->
            ( { feed | filters = feed.filters |> EverySet.toggle filter }, Cmd.none )


viewFilter : (Msg -> msg) -> Filters -> Filter -> Html msg
viewFilter wrap filters filter =
    let
        ( label, description ) =
            case filter of
                FavouriteFilter ->
                    ( "Only Favourite Games", "Only show events for games you have marked as favourites." )

                NewBetFilter ->
                    ( "New Bets", "Show new bets that have been added recently." )

                BetCompleteFilter ->
                    ( "Bet Finished", "Show bets that have finished recently." )

                NotableStakeFilter ->
                    ( "Big Bets", "Show big bets people have placed recently." )
    in
    FilterChip.chip label
        |> FilterChip.button (ToggleFilter filter |> wrap |> Just)
        |> FilterChip.selected (filters |> EverySet.member filter)
        |> FilterChip.attrs [ HtmlA.title description ]
        |> FilterChip.view


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
                ]

        body items =
            let
                filteredItems =
                    if not specificFeed then
                        let
                            filter =
                                filterBy
                                    feed.filters
                                    { favouriteGames = bets.favourites.value }
                        in
                        items |> List.filter (\{ event } -> filter event)

                    else
                        items

                events =
                    if filteredItems |> List.isEmpty then
                        Html.p [ HtmlA.class "empty" ] [ Icon.ghost |> Icon.view, Html.span [] [ Html.text "No matching events." ] ]

                    else
                        filteredItems |> List.map viewItem |> Html.ol []

                filters =
                    if specificFeed then
                        []

                    else
                        [ possibleFilters
                            |> List.map (viewFilter wrap feed.filters)
                            |> Filtering.viewFilters "Events" (items |> List.length) (filteredItems |> List.length)
                        ]
            in
            List.append filters [ events ]
    in
    prefix ++ Api.viewData Api.viewOrError body feed.items
