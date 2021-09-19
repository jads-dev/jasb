port module JoeBets.Ports exposing
    ( storeCmd
    , storeSub
    )

import Json.Decode as JsonD
import Json.Encode as JsonE


port storeCmd : JsonE.Value -> Cmd msg


port storeSub : (JsonD.Value -> msg) -> Sub msg
