module Util.EverySet exposing
    ( setMembership
    , toggle
    )

import EverySet exposing (..)


setMembership : Bool -> item -> EverySet item -> EverySet item
setMembership desiredMembership =
    if desiredMembership then
        insert

    else
        remove


toggle : item -> EverySet item -> EverySet item
toggle item set =
    setMembership (member item set |> not) item set
