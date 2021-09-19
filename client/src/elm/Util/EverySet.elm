module Util.EverySet exposing (setMembership)

import EverySet exposing (..)


setMembership : Bool -> item -> EverySet item -> EverySet item
setMembership desiredMembership =
    if desiredMembership then
        EverySet.insert

    else
        EverySet.remove
