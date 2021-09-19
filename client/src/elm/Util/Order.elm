module Util.Order exposing (reverse)


reverse : Order -> Order
reverse order =
    case order of
        LT ->
            GT

        EQ ->
            EQ

        GT ->
            LT
