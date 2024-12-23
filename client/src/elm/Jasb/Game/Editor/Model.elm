module Jasb.Game.Editor.Model exposing
    ( Body
    , Model
    , Msg(..)
    , encodeBody
    )

import Jasb.Api.Action as Api
import Jasb.Api.Data as Api
import Jasb.Api.Model as Api
import Jasb.Editing.Slug exposing (Slug)
import Jasb.Editing.Uploader as Uploader exposing (Uploader)
import Jasb.Game.Id as Game
import Jasb.Game.Model exposing (Game)
import Json.Encode as JsonE
import Time.Date as Date exposing (Date)
import Util.Json.Encode as JsonE


type alias Model =
    { source : Maybe ( Game.Id, Api.Data Game )
    , id : Slug Game.Id
    , name : String
    , cover : Uploader
    , bets : Int
    , start : String
    , finish : String
    , order : Maybe Int
    , saving : Api.ActionState
    }


type alias Body =
    { version : Maybe Int
    , name : Maybe String
    , cover : Maybe String
    , started : Maybe (Maybe Date)
    , finished : Maybe (Maybe Date)
    , order : Maybe (Maybe Int)
    }


encodeBody : Body -> JsonE.Value
encodeBody { version, name, cover, started, finished, order } =
    JsonE.partialObject
        [ ( "version", version |> Maybe.map JsonE.int )
        , ( "name", name |> Maybe.map JsonE.string )
        , ( "cover", cover |> Maybe.map JsonE.string )
        , ( "started", started |> Maybe.map (Maybe.map Date.encode >> Maybe.withDefault JsonE.null) )
        , ( "finished", finished |> Maybe.map (Maybe.map Date.encode >> Maybe.withDefault JsonE.null) )
        , ( "order", order |> Maybe.map (Maybe.map JsonE.int >> Maybe.withDefault JsonE.null) )
        ]


type Msg
    = Load Game.Id (Api.Response Game)
    | Reset
    | ChangeId String
    | ChangeName String
    | CoverMsg Uploader.Msg
    | ChangeStart String
    | ChangeFinish String
    | ChangeOrder String
    | Save
    | Saved Game.Id (Api.Response Game)
