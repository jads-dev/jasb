port module Jasb.Ports exposing
    ( scrollCmd
    , selectCmd
    , sessionStoreCmd
    , sessionStoreSub
    , storeCmd
    , storeSub
    , webSocketCmd
    , webSocketSub
    )

import Json.Decode as JsonD
import Json.Encode as JsonE


port scrollCmd : JsonE.Value -> Cmd msg


port selectCmd : JsonE.Value -> Cmd msg


port storeCmd : JsonE.Value -> Cmd msg


port storeSub : (JsonD.Value -> msg) -> Sub msg


port sessionStoreCmd : JsonE.Value -> Cmd msg


port sessionStoreSub : (JsonD.Value -> msg) -> Sub msg


port webSocketCmd : JsonE.Value -> Cmd msg


port webSocketSub : (JsonD.Value -> msg) -> Sub msg
