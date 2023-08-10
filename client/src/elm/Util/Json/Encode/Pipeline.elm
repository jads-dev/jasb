module Util.Json.Encode.Pipeline exposing
    ( ArrayPipeline
    , ObjectPipeline
    , add
    , field
    , finishArray
    , finishObject
    , maybeAdd
    , maybeField
    , mergeArray
    , mergeObject
    , startArray
    , startObject
    )

import Json.Encode exposing (..)


type ObjectPipeline
    = ObjectPipeline (List ( String, Value ))


startObject : ObjectPipeline
startObject =
    ObjectPipeline []


field : String -> (value -> Value) -> value -> ObjectPipeline -> ObjectPipeline
field name encodeValue value (ObjectPipeline fields) =
    (( name, encodeValue value ) :: fields) |> ObjectPipeline


maybeField : String -> (value -> Value) -> Maybe value -> ObjectPipeline -> ObjectPipeline
maybeField name encodeValue maybeValue =
    maybeValue |> Maybe.map (field name encodeValue) |> Maybe.withDefault identity


mergeObject : ObjectPipeline -> ObjectPipeline -> ObjectPipeline
mergeObject (ObjectPipeline after) (ObjectPipeline before) =
    after ++ before |> ObjectPipeline


finishObject : ObjectPipeline -> Value
finishObject (ObjectPipeline fields) =
    fields |> List.reverse |> object


type ArrayPipeline
    = ArrayPipeline (List Value)


startArray : ArrayPipeline
startArray =
    ArrayPipeline []


add : Value -> ArrayPipeline -> ArrayPipeline
add value (ArrayPipeline values) =
    (value :: values) |> ArrayPipeline


maybeAdd : (value -> Value) -> Maybe value -> ArrayPipeline -> ArrayPipeline
maybeAdd encodeValue maybeValue =
    maybeValue |> Maybe.map (encodeValue >> add) |> Maybe.withDefault identity


mergeArray : ArrayPipeline -> ArrayPipeline -> ArrayPipeline
mergeArray (ArrayPipeline after) (ArrayPipeline before) =
    after ++ before |> ArrayPipeline


finishArray : ArrayPipeline -> Value
finishArray (ArrayPipeline values) =
    values |> List.reverse |> list identity
