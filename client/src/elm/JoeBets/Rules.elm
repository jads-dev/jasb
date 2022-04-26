module JoeBets.Rules exposing
    ( initialBalance
    , maxStakeWhileInDebt
    , minStake
    , notableStake
    )


initialBalance : Int
initialBalance =
    1000


maxStakeWhileInDebt : Int
maxStakeWhileInDebt =
    100


notableStake : Int
notableStake =
    500


minStake : Int
minStake =
    25
