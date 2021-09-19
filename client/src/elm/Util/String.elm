module Util.String exposing (plural)


plural : Int -> String
plural amount =
    if amount == 1 then
        ""

    else
        "s"
