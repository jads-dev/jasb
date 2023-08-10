port module JoeBets.Ports exposing
    ( copyImageCmd
    , sessionStoreCmd
    , sessionStoreSub
    , storeCmd
    , storeSub
    , webSocketCmd
    , webSocketSub
    )

import Json.Decode as JsonD
import Json.Encode as JsonE


port storeCmd : JsonE.Value -> Cmd msg


port storeSub : (JsonD.Value -> msg) -> Sub msg


port sessionStoreCmd : JsonE.Value -> Cmd msg


port sessionStoreSub : (JsonD.Value -> msg) -> Sub msg


port webSocketCmd : JsonE.Value -> Cmd msg


port webSocketSub : (JsonD.Value -> msg) -> Sub msg


port copyImageCmd : JsonE.Value -> Cmd msg
