module Jasb.WebSocket exposing
    ( connect
    , disconnect
    , listen
    )

import Jasb.Api as Api
import Jasb.Api.Path as Api
import Jasb.Ports as Ports
import Json.Decode as JsonD
import Json.Encode as JsonE


connect : Api.Path -> Cmd msg
connect =
    Api.relativeUrl >> JsonE.string >> Ports.webSocketCmd


disconnect : Cmd msg
disconnect =
    JsonE.null |> Ports.webSocketCmd


listen : JsonD.Decoder a -> (Result JsonD.Error a -> msg) -> Sub msg
listen decoder wrap =
    let
        decodeAndwrap =
            JsonD.decodeValue JsonD.string
                >> Result.andThen (JsonD.decodeString decoder)
                >> wrap
    in
    Ports.webSocketSub decodeAndwrap
