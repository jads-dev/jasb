module Jasb.Store.Item exposing
    ( Codec
    , Item
    , default
    , delete
    , get
    , initial
    , itemDecoder
    , newMigration
    , set
    )

import Jasb.Store.Model exposing (Key, encodeKey)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE


type alias Item value =
    { value : value
    , schemaVersion : Int
    , documentVersion : Int
    }


type Codec value
    = Codec (InternalCodec value)


type alias InternalCodec value =
    { key : Key
    , version : Int
    , decoder : Int -> JsonD.Decoder value
    , encode : value -> JsonE.Value
    , defaultValue : value
    }


decoderForVersion : Int -> JsonD.Decoder value -> (Int -> JsonD.Decoder value) -> Int -> JsonD.Decoder value
decoderForVersion targetVersion decoder oldDecoder version =
    if version == targetVersion then
        decoder

    else if version > targetVersion then
        JsonD.fail "Future version, unable to decode."

    else
        oldDecoder version


initial : Key -> JsonD.Decoder value -> (value -> JsonE.Value) -> value -> Codec value
initial key decoder encode defaultValue =
    Codec
        { key = key
        , version = 0
        , decoder = decoderForVersion 0 decoder (\_ -> "Negative version number." |> JsonD.fail)
        , encode = encode
        , defaultValue = defaultValue
        }


newMigration : JsonD.Decoder value -> (value -> JsonE.Value) -> (oldValue -> value) -> value -> Codec oldValue -> Codec value
newMigration decoder encode upgrade defaultValue (Codec old) =
    let
        version =
            old.version + 1
    in
    Codec
        { key = old.key
        , version = version
        , decoder = decoderForVersion version decoder (old.decoder >> JsonD.map upgrade)
        , encode = encode
        , defaultValue = defaultValue
        }


default : Codec value -> Item value
default (Codec { defaultValue, version }) =
    Item defaultValue version -1


itemDecoder : Codec value -> JsonD.Decoder (Item value)
itemDecoder ((Codec { decoder }) as codec) =
    let
        decodeForVersion givenVersion =
            JsonD.succeed Item
                |> JsonD.required "value" (decoder givenVersion)
                |> JsonD.hardcoded givenVersion
                |> JsonD.required "documentVersion" JsonD.int
    in
    JsonD.succeed identity
        |> JsonD.optional "item" (JsonD.field "schemaVersion" JsonD.int |> JsonD.andThen decodeForVersion) (default codec)


get : Key -> JsonE.Value
get key =
    [ ( "op", "Get" |> JsonE.string )
    , ( "key", key |> encodeKey )
    ]
        |> JsonE.object


set : Codec value -> Maybe (Item value) -> value -> JsonE.Value
set (Codec { key, encode, version }) oldValue value =
    let
        extra =
            case oldValue of
                Just { documentVersion } ->
                    [ ( "ifDocumentVersion", documentVersion |> JsonE.int ) ]

                Nothing ->
                    []
    in
    [ [ ( "op", "Set" |> JsonE.string )
      , ( "key", key |> encodeKey )
      , ( "value", value |> encode )
      , ( "schemaVersion", version |> JsonE.int )
      ]
    , extra
    ]
        |> List.concat
        |> JsonE.object


delete : Codec value -> Maybe (Item value) -> JsonE.Value
delete (Codec { key }) oldValue =
    let
        extra =
            case oldValue of
                Just { documentVersion } ->
                    [ ( "ifDocumentVersion", documentVersion |> JsonE.int ) ]

                Nothing ->
                    []
    in
    [ [ ( "op", "Delete" |> JsonE.string )
      , ( "key", key |> encodeKey )
      ]
    , extra
    ]
        |> List.concat
        |> JsonE.object
