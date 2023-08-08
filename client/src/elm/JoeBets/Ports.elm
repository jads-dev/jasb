port module JoeBets.Ports exposing
    ( sessionStoreCmd
    , sessionStoreSub
    , storeCmd
    , storeSub
    )

import Json.Decode as JsonD
import Json.Encode as JsonE


port storeCmd : JsonE.Value -> Cmd msg


port storeSub : (JsonD.Value -> msg) -> Sub msg


port sessionStoreCmd : JsonE.Value -> Cmd msg


port sessionStoreSub : (JsonD.Value -> msg) -> Sub msg
