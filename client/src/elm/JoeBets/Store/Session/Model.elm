module JoeBets.Store.Session.Model exposing
    ( Key(..)
    , KeyedValue(..)
    , encodeKey
    , keyAndValue
    , keyDecoder
    , keyToString
    , valueDecoder
    )

import JoeBets.Api exposing (AuthPath(..))
import JoeBets.Route as Route exposing (Route)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Util.Json.Decode as JsonD


type Key
    = LoginRedirect


keyDecoder : JsonD.Decoder Key
keyDecoder =
    let
        byName name =
            case String.split ":" name of
                [ "login-redirect" ] ->
                    LoginRedirect |> JsonD.succeed

                _ ->
                    name |> JsonD.unknownValue "store key"
    in
    JsonD.string |> JsonD.andThen byName


keyToString : Key -> String
keyToString =
    let
        toList key =
            case key of
                LoginRedirect ->
                    [ "login-redirect" ]
    in
    toList >> String.join ":"


encodeKey : Key -> JsonE.Value
encodeKey =
    keyToString >> JsonE.string


type KeyedValue
    = LoginRedirectValue (Maybe Route)


valueDecoder : JsonD.Decoder KeyedValue
valueDecoder =
    let
        fromKey key =
            case key of
                LoginRedirect ->
                    JsonD.succeed LoginRedirectValue
                        |> JsonD.optionalAsMaybe "value" Route.decoder
    in
    JsonD.field "key" keyDecoder |> JsonD.andThen fromKey


keyAndValue : KeyedValue -> ( Key, Maybe JsonE.Value )
keyAndValue keyedValue =
    case keyedValue of
        LoginRedirectValue route ->
            ( LoginRedirect
            , route |> Maybe.map Route.encode
            )
