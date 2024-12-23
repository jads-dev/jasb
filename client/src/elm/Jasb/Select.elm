module Jasb.Select exposing (select)

import Jasb.Ports as Ports
import Json.Encode as JsonE


select : String -> Cmd msg
select =
    JsonE.string >> Ports.selectCmd
