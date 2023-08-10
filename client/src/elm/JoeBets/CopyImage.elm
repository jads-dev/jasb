module JoeBets.CopyImage exposing (ofId)

import JoeBets.Ports as Ports
import Json.Encode as JsonE


ofId : String -> Cmd msg
ofId =
    JsonE.string >> Ports.copyImageCmd
