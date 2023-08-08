module JoeBets.Bet exposing
    ( UserCapability
    , notLoggedIn
    , readOnlyFromAuth
    , readWriteFromAuth
    , view
    , viewFiltered
    , viewSummarised
    )

import AssocList
import EverySet
import FontAwesome as Icon
import FontAwesome.Regular as IconRegular
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Keyed as HtmlK
import JoeBets.Bet.Maths as Bet
import JoeBets.Bet.Model as Bet exposing (..)
import JoeBets.Bet.Option as Option
import JoeBets.Bet.PlaceBet.Model as PlaceBet
import JoeBets.Bet.Stakes as Stakes
import JoeBets.Coins as Coins
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game
import JoeBets.Page.Bets.Filters as Filters
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Page.Edit.Model as Edit
import JoeBets.Route as Route
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Model as User
import Material.IconButton as IconButton
import Svg.Attributes as SvgA
import Time.Model as Time
import Util.Html as Html
import Util.List as List
import Util.Maybe as Maybe


type alias UserCapability msg =
    Maybe ( User.WithId, Maybe (PlaceBet.Msg -> msg) )


localUserCapability : UserCapability msg -> Maybe User.WithId
localUserCapability =
    Maybe.map Tuple.first


wrapCapability : UserCapability msg -> Maybe ( User.WithId, PlaceBet.Msg -> msg )
wrapCapability =
    Maybe.andThen (\( user, wrap ) -> wrap |> Maybe.map (\w -> ( user, w )))


readWriteFromAuth : (PlaceBet.Msg -> msg) -> Auth.Model -> UserCapability msg
readWriteFromAuth wrap { localUser } =
    localUser |> Maybe.map (\user -> ( user, Just wrap ))


readOnlyFromAuth : Auth.Model -> UserCapability msg
readOnlyFromAuth { localUser } =
    localUser |> Maybe.map (\user -> ( user, Nothing ))


notLoggedIn : UserCapability msg
notLoggedIn =
    Nothing


hasVotedInBet : Bet -> UserCapability msg -> Bool
hasVotedInBet bet =
    localUserCapability
        >> Maybe.map (.id >> Bet.hasAnyStake bet)
        >> Maybe.withDefault False


view : Time.Context -> UserCapability msg -> Game.Id -> String -> Bet.Id -> Bet -> Html msg
view timeContext userCapability gameId gameName betId bet =
    internalView timeContext
        userCapability
        Detailed
        Nothing
        (hasVotedInBet bet userCapability)
        gameId
        gameName
        betId
        bet


viewSummarised : Time.Context -> UserCapability msg -> Maybe User.Id -> Game.Id -> String -> Bet.Id -> Bet -> Html msg
viewSummarised timeContext userCapability highlight gameId gameName betId bet =
    internalView timeContext
        userCapability
        Summarised
        highlight
        (hasVotedInBet bet userCapability)
        gameId
        gameName
        betId
        bet


viewFiltered : Time.Context -> UserCapability msg -> Bets.Subset -> Filters.Resolved -> Game.Id -> String -> Bet.Id -> Bet -> Maybe (Html msg)
viewFiltered timeContext userCapability subset filters gameId gameName betId bet =
    let
        hasVoted =
            hasVotedInBet bet userCapability

        progress =
            case subset of
                Bets.Active ->
                    case bet.progress of
                        Bet.Voting _ ->
                            filters.voting

                        Bet.Locked _ ->
                            filters.locked

                        Bet.Complete _ ->
                            filters.complete

                        Cancelled _ ->
                            filters.cancelled

                Bets.Suggestions ->
                    case bet.progress of
                        _ ->
                            False
    in
    if progress && (not bet.spoiler || filters.spoilers) && (not hasVoted || filters.hasBet) then
        internalView timeContext
            userCapability
            Summarised
            Nothing
            hasVoted
            gameId
            gameName
            betId
            bet
            |> Just

    else
        Nothing


type ViewType
    = Summarised
    | Detailed


internalView : Time.Context -> UserCapability msg -> ViewType -> Maybe User.Id -> Bool -> Game.Id -> String -> Bet.Id -> Bet -> Html msg
internalView timeContext userCapability viewType highlight hasVoted gameId gameName betId bet =
    let
        optionStakes =
            bet.options |> AssocList.values |> List.map .stakes

        numberOfStakes =
            optionStakes |> List.map AssocList.size |> List.sum

        amounts =
            optionStakes |> List.map (AssocList.values >> List.map .amount >> List.sum)

        maxAmount =
            amounts |> List.maximum |> Maybe.withDefault 0

        totalAmount =
            amounts |> List.sum

        ( canVoteOnBet, maybeWinners ) =
            case bet.progress of
                Voting _ ->
                    ( True, EverySet.empty )

                Locked _ ->
                    ( False, EverySet.empty )

                Complete { winners } ->
                    ( False, winners )

                Cancelled _ ->
                    ( False, EverySet.empty )

        viewOption ( optionId, { name, stakes } as option ) =
            let
                findAction ( { id }, wrap ) =
                    let
                        existingStake =
                            AssocList.get id stakes

                        existingAmount =
                            existingStake |> Maybe.map .amount

                        canVoteForThisOption =
                            let
                                notLocked =
                                    existingStake
                                        |> Maybe.map (.message >> (==) Nothing)
                                        |> Maybe.withDefault True
                            in
                            canVoteOnBet && notLocked
                    in
                    PlaceBet.Target gameId gameName betId bet optionId option.name existingAmount
                        |> PlaceBet.Start
                        |> wrap
                        |> Maybe.when canVoteForThisOption

                action =
                    userCapability
                        |> wrapCapability
                        |> Maybe.andThen findAction

                votedFor =
                    userCapability
                        |> localUserCapability
                        |> Maybe.andThen (\{ id } -> stakes |> AssocList.get id |> Maybe.map .amount)
                        |> (/=) Nothing

                classes =
                    HtmlA.classList [ ( "voted-for", votedFor ), ( "winner", EverySet.member optionId maybeWinners ) ]

                stakeCount =
                    stakes |> AssocList.size

                totalStake =
                    stakes |> AssocList.values |> List.map .amount |> List.sum

                ratio =
                    Bet.ratio totalAmount totalStake

                ratioDescription =
                    case bet.progress of
                        Complete { winners } ->
                            if winners |> EverySet.member optionId then
                                "This option paid out at this ratio."

                            else
                                "This option lost, but would have paid at this ratio if it had won."

                        Cancelled _ ->
                            "This bet was cancelled, but this option would have paid at this ratio if it had won."

                        Locked _ ->
                            "This option will pay out at this ratio if it wins."

                        Voting _ ->
                            "If this option wins, a bet on it will currently pay out at this return ratio. This will change as more is staked in the bet."

                ( betDescription, betIcon ) =
                    if votedFor then
                        ( "Change Bet", IconRegular.squareCheck )

                    else
                        ( "Place Bet", IconRegular.square )

                people =
                    if stakeCount == 1 then
                        "person has"

                    else
                        "people have"

                title =
                    [ stakeCount |> String.fromInt, " ", people, " staked a total of ", totalStake |> String.fromInt, "." ]
                        |> String.concat
            in
            ( optionId |> Option.idToString
            , Html.li [ classes ]
                [ option.image |> Maybe.map (\url -> Html.img [ HtmlA.src url ] []) |> Maybe.withDefault (Html.text "")
                , Html.div [ HtmlA.class "details" ]
                    [ Html.span [ HtmlA.class "name" ] [ Html.text name ]
                    , Html.span [ HtmlA.class "button" ] [ IconButton.view (Icon.view betIcon) betDescription action ]
                    , Stakes.view timeContext (userCapability |> localUserCapability) highlight maxAmount stakes
                    ]
                , Html.div [ HtmlA.class "stats", HtmlA.title title ]
                    [ Html.span [ HtmlA.class "people" ]
                        [ Icon.user |> Icon.view
                        , stakeCount |> String.fromInt |> Html.text
                        ]
                    , totalStake |> Coins.view
                    , Html.span
                        [ HtmlA.class "ratio"
                        , HtmlA.title ratioDescription
                        ]
                        [ Html.text "", Html.text ratio ]
                    ]
                ]
            )

        ( class, icon, progressDescription ) =
            case bet.progress of
                Voting { lockMoment } ->
                    ( "voting", Icon.voteYea, "The bet is open. You can place bets until " ++ lockMoment ++ "." )

                Locked _ ->
                    ( "locked", Icon.lock, "The bet is locked, awaiting the result, you can no longer place bets." )

                Complete _ ->
                    ( "complete", Icon.check, "The bet is finished, you can no longer place bets." )

                Cancelled { reason } ->
                    ( "cancelled", Icon.times, "The bet has been cancelled because " ++ reason ++ ", and all bets refunded." )

        votedDetail =
            if hasVoted then
                [ Html.span [ HtmlA.class "voted", HtmlA.title "You have placed a bet." ]
                    [ Icon.userCheck |> Icon.view ]
                ]

            else
                []

        extraByProgress =
            case bet.progress of
                Voting { lockMoment } ->
                    [ Html.p []
                        [ Html.text "You can place bets, or modify your bet, until "
                        , Html.text lockMoment
                        , Html.text ". Click the square by the option you think will win to place a bet, or to edit/refund an existing bet."
                        ]
                    ]

                Locked _ ->
                    [ Html.p [] [ Html.text "A total of ", Coins.view totalAmount, Html.text " has been bet." ]
                    , Html.p [] [ Html.text "You can no longer place or modify bets. When the result is clear the bets will be resolved." ]
                    ]

                Complete { winners } ->
                    let
                        nameOfOption ( id, option ) =
                            if EverySet.member id winners then
                                Just ("“" ++ option.name ++ "”")

                            else
                                Nothing

                        winningOptions =
                            bet.options
                                |> AssocList.toList
                                |> List.filterMap nameOfOption
                                |> List.intersperse ", "
                                |> List.addBeforeLast "and "
                                |> String.concat
                    in
                    [ Html.p [] [ Html.text "This bet is over: ", Html.text winningOptions, Html.text " won." ]
                    , Html.p []
                        [ Html.text "A total of "
                        , Coins.view totalAmount
                        , Html.text " has been distributed to the winners."
                        ]
                    ]

                Cancelled { reason } ->
                    [ Html.p [] [ Html.text "The bet has been cancelled because ", Html.text reason, Html.text "." ]
                    , Html.p [] [ Html.text "All bets have been refunded." ]
                    ]

        adminContent =
            if userCapability |> localUserCapability |> Auth.canManageBets gameId then
                [ Html.div [ HtmlA.class "admin-controls" ]
                    [ Route.a (betId |> Edit.Edit |> Edit.Bet gameId |> Route.Edit) [] [ Icon.pen |> Icon.view ]
                    ]
                ]

            else
                []

        ( outer, inner ) =
            case viewType of
                Summarised ->
                    ( Html.details
                    , \attrs nodes -> Html.summary [] [ Html.div attrs nodes, Html.summaryMarker ]
                    )

                Detailed ->
                    ( Html.div, Html.div )

        summaryContent =
            [ [ Html.h3 [ HtmlA.classList [ ( "potential-spoiler", bet.spoiler ) ] ]
                    [ Route.a (Route.Bet gameId betId)
                        []
                        [ Html.text bet.name
                        , Icon.link |> Icon.styled [ SvgA.class "permalink" ] |> Icon.view
                        ]
                    ]
              ]
            , votedDetail
            , [ Html.span [ HtmlA.class "progress", HtmlA.title progressDescription ]
                    [ icon |> Icon.view ]
              , Html.span [ HtmlA.class "total-votes" ]
                    [ numberOfStakes |> String.fromInt |> Html.text, Html.text " bets placed." ]
              , Html.p [ HtmlA.classList [ ( "description", True ), ( "potential-spoiler", bet.spoiler ) ] ]
                    [ Html.text bet.description ]
              , Html.div [ HtmlA.class "interactions" ] adminContent
              ]
            ]
                |> List.concat

        content =
            outer [ HtmlA.class "bet", HtmlA.class class, betId |> Bet.idToString |> HtmlA.id ]
                [ summaryContent |> inner [ HtmlA.class "summary" ]
                , Html.div [ HtmlA.class "extra" ] extraByProgress
                , HtmlK.ul [] (bet.options |> AssocList.toList |> List.map viewOption)
                ]
    in
    content
