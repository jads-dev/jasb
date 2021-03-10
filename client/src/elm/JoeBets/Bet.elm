module JoeBets.Bet exposing
    ( view
    , viewFiltered
    , voteAsFromAuth
    )

import AssocList
import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Keyed as HtmlK
import JoeBets.Bet.Maths as Bet
import JoeBets.Bet.Model as Bet exposing (..)
import JoeBets.Bet.Option as Option exposing (Option)
import JoeBets.Bet.PlaceBet.Model as PlaceBet
import JoeBets.Bet.Stakes as Stakes
import JoeBets.Game.Model as Game
import JoeBets.Page.Bets.Model exposing (Filters, ResolvedFilters)
import JoeBets.Page.Edit.Model as Edit
import JoeBets.Route as Route
import JoeBets.User as User
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Model as User exposing (User)
import Material.Button as Button
import Util.Maybe as Maybe


type alias VoteAs msg =
    Maybe { id : User.Id, user : User, wrap : PlaceBet.Msg -> msg }


voteAsFromAuth : (PlaceBet.Msg -> msg) -> Auth.Model -> VoteAs msg
voteAsFromAuth wrap auth =
    auth.localUser |> Maybe.map (\{ id, user } -> { id = id, user = user, wrap = wrap })


view : VoteAs msg -> Game.Id -> String -> Bet.Id -> Bet -> Html msg
view voteAs gameId gameName betId bet =
    let
        hasVoted =
            voteAs |> Maybe.map (.id >> Bet.hasAnyStake bet) |> Maybe.withDefault False
    in
    internalView voteAs Detailed hasVoted gameId gameName betId bet


viewFiltered : VoteAs msg -> ResolvedFilters -> Game.Id -> String -> Bet.Id -> Bet -> Maybe (Html msg)
viewFiltered voteAs filters gameId gameName betId bet =
    let
        hasVoted =
            voteAs |> Maybe.map (.id >> Bet.hasAnyStake bet) |> Maybe.withDefault False

        progress =
            case bet.progress of
                Bet.Suggestion _ ->
                    False

                Bet.Voting _ ->
                    filters.voting

                Bet.Locked _ ->
                    filters.locked

                Bet.Complete _ ->
                    filters.complete

                Cancelled _ ->
                    filters.cancelled
    in
    if progress && (not bet.spoiler || filters.spoilers) && (not hasVoted || filters.hasBet) then
        internalView voteAs Summarised hasVoted gameId gameName betId bet |> Just

    else
        Nothing


type ViewType
    = Summarised
    | Detailed


internalView : VoteAs msg -> ViewType -> Bool -> Game.Id -> String -> Bet.Id -> Bet -> Html msg
internalView voteAs viewType hasVoted gameId gameName betId bet =
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

        ( canVote, maybeWinner ) =
            case bet.progress of
                Suggestion _ ->
                    ( False, Nothing )

                Voting _ ->
                    ( True, Nothing )

                Locked _ ->
                    ( False, Nothing )

                Complete { winner } ->
                    ( False, Just winner )

                Cancelled { reason } ->
                    ( False, Nothing )

        viewOption ( optionId, { name, stakes } as option ) =
            let
                ( action, votedFor ) =
                    case voteAs of
                        Just { id, user, wrap } ->
                            let
                                existingAmount =
                                    AssocList.get id stakes |> Maybe.map .amount

                                hasExistingBet =
                                    existingAmount /= Nothing

                                canVoteForThisOption =
                                    let
                                        hasNoBalance =
                                            user.balance < 1

                                        canPlaceNewBet =
                                            not (hasNoBalance && Bet.hasAnyOtherStake bet id optionId)
                                    in
                                    canVote && (canPlaceNewBet || hasExistingBet)
                            in
                            ( PlaceBet.Target gameId gameName betId bet optionId option.name existingAmount
                                |> PlaceBet.Start
                                |> wrap
                                |> Maybe.when canVoteForThisOption
                            , hasExistingBet
                            )

                        Nothing ->
                            ( Nothing, False )

                classes =
                    HtmlA.classList [ ( "voted-for", votedFor ), ( "winner", Just optionId == maybeWinner ) ]

                stakeCount =
                    stakes |> AssocList.size

                totalStake =
                    stakes |> AssocList.values |> List.map .amount |> List.sum

                ratio =
                    Bet.ratio totalAmount totalStake

                ratioDescription =
                    case bet.progress of
                        Complete { winner } ->
                            if winner == optionId then
                                "This option paid out at this ratio."

                            else
                                "This option lost, but would have paid at this ratio if it had won."

                        Cancelled _ ->
                            "This bet was cancelled, but this option would have paid at this ratio if it had won."

                        Locked _ ->
                            "This option will pay out at this ratio if it wins."

                        Voting _ ->
                            "If this option wins, a bet on it will currently pay out at this return ratio. This will change as votes come in."

                        Suggestion _ ->
                            ""

                style =
                    if votedFor then
                        Button.Unelevated

                    else
                        Button.Raised

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
                [ option.image |> Maybe.map (\url -> Html.img [ HtmlA.src url ] []) |> Maybe.withDefault (Html.div [] [])
                , Button.view style Button.Padded name Nothing action
                , Stakes.view (voteAs |> Maybe.map .id) maxAmount stakes
                , Html.div [ HtmlA.class "details", HtmlA.title title ]
                    [ Html.span [ HtmlA.class "people" ]
                        [ Icon.user |> Icon.present |> Icon.view
                        , stakeCount |> String.fromInt |> Html.text
                        ]
                    , totalStake |> User.viewBalance
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
                Suggestion _ ->
                    ( "suggestion", Icon.lightbulb |> Icon.present, "This is a suggestion, you can't place bets until it is approved." )

                Voting { locksWhen } ->
                    ( "voting", Icon.voteYea |> Icon.present, "The bet is open until " ++ locksWhen ++ ", you can place bets." )

                Locked _ ->
                    ( "locked", Icon.lock |> Icon.present, "The bet is locked, awaiting the result, you can no longer place bets." )

                Complete { winner } ->
                    ( "complete", Icon.check |> Icon.present, "The bet is finished, you can no longer place bets." )

                Cancelled { reason } ->
                    ( "cancelled", Icon.times |> Icon.present, "The bet has been cancelled because " ++ reason ++ ", and all bets refunded." )

        votedDetail =
            if hasVoted then
                [ Html.span [ HtmlA.class "voted", HtmlA.title "You have placed a bet." ]
                    [ Icon.userCheck |> Icon.present |> Icon.view ]
                ]

            else
                []

        details =
            [ votedDetail
            , [ Html.span [ HtmlA.class "progress", HtmlA.title progressDescription ]
                    [ icon |> Icon.view ]
              , Html.span [ HtmlA.class "total-votes" ]
                    [ numberOfStakes |> String.fromInt |> Html.text, Html.text " bets placed." ]
              ]
            ]

        extraByProgress =
            case bet.progress of
                Suggestion _ ->
                    [ Html.p [] [ Html.text "This is a suggestion, it needs to be approved to bet on it." ] ]

                Voting { locksWhen } ->
                    [ Html.p []
                        [ Html.text "You can place bets, or modify your bet, until "
                        , Html.text locksWhen
                        , Html.text "."
                        ]
                    ]

                Locked _ ->
                    [ Html.p [] [ Html.text "A total of ", User.viewBalance totalAmount, Html.text " has been bet." ]
                    , Html.p [] [ Html.text "You can no longer place or modify bets. When the result is clear the bets will be resolved." ]
                    ]

                Complete { winner } ->
                    let
                        winningOption =
                            bet.options
                                |> AssocList.get winner
                                |> Maybe.map .name
                                |> Maybe.withDefault "[Error: Winning option not found.]"
                    in
                    [ Html.p [] [ Html.text "This bet is over, ", Html.text winningOption, Html.text " won." ]
                    , Html.p []
                        [ Html.text "A total of "
                        , User.viewBalance totalAmount
                        , Html.text " has been distributed to the winners."
                        ]
                    ]

                Cancelled { reason } ->
                    [ Html.p [] [ Html.text "The bet has been cancelled because ", Html.text reason, Html.text "." ]
                    , Html.p [] [ Html.text "All bets have been refunded." ]
                    ]

        adminContent =
            if voteAs |> Auth.isMod gameId then
                [ Html.div [ HtmlA.class "admin-controls" ]
                    [ Route.a (betId |> Just |> Edit.Bet gameId |> Route.Edit) [] [ Icon.pen |> Icon.present |> Icon.view ]
                    ]
                ]

            else
                []

        ( outer, inner ) =
            case viewType of
                Summarised ->
                    ( Html.details, Html.summary )

                Detailed ->
                    ( Html.div, Html.div )

        content =
            outer [ HtmlA.class "bet", HtmlA.class class, betId |> Bet.idToString |> HtmlA.id ]
                [ inner [ HtmlA.class "summary" ]
                    [ Html.div [ HtmlA.class "top" ]
                        [ Route.a (Route.Bet gameId betId)
                            [ HtmlA.class "permalink" ]
                            [ Html.h3 []
                                [ Html.text bet.name
                                , Icon.link |> Icon.present |> Icon.view
                                ]
                            ]
                        , details |> List.concat |> Html.div [ HtmlA.class "details" ]
                        ]
                    , Html.p [ HtmlA.class "description" ] [ Html.text bet.description ]
                    , Html.div [] adminContent
                    ]
                , Html.div [ HtmlA.class "extra" ] extraByProgress
                , HtmlK.ul [] (bet.options |> AssocList.toList |> List.map viewOption)
                ]
    in
    content
