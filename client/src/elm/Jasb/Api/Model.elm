module Jasb.Api.Model exposing
    ( Process(..)
    , Response
    )

import Jasb.Api.Error exposing (Error)


type alias Response value =
    Result Error value


type Process value
    = Start
    | Finish (Response value)
