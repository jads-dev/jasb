module JoeBets.Api.Model exposing
    ( Process(..)
    , Response
    )

import JoeBets.Api.Error exposing (Error)


type alias Response value =
    Result Error value


type Process value
    = Start
    | Finish (Response value)
