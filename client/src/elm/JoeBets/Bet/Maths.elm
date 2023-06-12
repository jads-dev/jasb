module JoeBets.Bet.Maths exposing
    ( hasAnyOtherStake
    , hasAnyStake
    , ratio
    )

import AssocList
import JoeBets.Bet.Model exposing (Bet)
import JoeBets.Bet.Option as Option
import JoeBets.Rules as Rules
import JoeBets.User.Model as User
import List.Extra as List
import Round


hasAnyOtherStake : Bet -> User.Id -> Option.Id -> Bool
hasAnyOtherStake bet localUserId optionId =
    bet.options
        |> AssocList.remove optionId
        |> AssocList.values
        |> List.any (.stakes >> AssocList.keys >> List.member localUserId)


hasAnyStake : Bet -> User.Id -> Bool
hasAnyStake bet localUserId =
    bet.options |> AssocList.values |> List.any (.stakes >> AssocList.member localUserId)


ratio : Int -> Int -> String
ratio stakesOnBet stakesOnOption =
    let
        ts =
            if stakesOnOption > 0 then
                stakesOnOption

            else
                -- Assume a minimum stake too avoid very excessive estimates.
                Rules.minStake

        raw =
            toFloat stakesOnBet / toFloat ts

        string =
            raw
                |> Round.round 2
                |> String.toList
                |> List.dropWhileRight ((==) '0')
                |> List.dropWhileRight ((==) '.')
                |> String.fromList
    in
    "1:" ++ string
