module Jasb.Rules exposing
    ( initialBalance
    , maxPity
    , maxStakeWhileInDebt
    , minStake
    , notableStake
    , scrapPerRoll
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
    10


maxPity : Int
maxPity =
    70


scrapPerRoll : Int
scrapPerRoll =
    5
