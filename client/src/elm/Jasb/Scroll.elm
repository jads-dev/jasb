module Jasb.Scroll exposing (elementIntoViewById)

import Jasb.Ports as Ports
import Json.Encode as JsonE


elementIntoViewById : String -> Cmd msg
elementIntoViewById =
    JsonE.string >> Ports.scrollCmd
