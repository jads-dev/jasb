module JoeBets.Game.Editor.Model exposing
    ( Body
    , Model
    , Msg(..)
    , encodeBody
    )

import JoeBets.Editing.Slug exposing (Slug)
import JoeBets.Editing.Uploader as Uploader exposing (Uploader)
import JoeBets.Game.Model as Game exposing (Game)
import Json.Encode as JsonE
import Time.Date as Date exposing (Date)
import Util.Json.Encode as JsonE
import Util.RemoteData as RemoteData exposing (RemoteData)


type alias Model =
    { source : Maybe ( Game.Id, RemoteData Game )
    , id : Slug Game.Id
    , name : String
    , cover : Uploader
    , igdbId : String
    , bets : Int
    , start : String
    , finish : String
    }


type alias Body =
    { version : Maybe Int
    , name : Maybe String
    , cover : Maybe String
    , igdbId : Maybe String
    , started : Maybe (Maybe Date)
    , finished : Maybe (Maybe Date)
    }


encodeBody : Body -> JsonE.Value
encodeBody { version, name, cover, igdbId, started, finished } =
    JsonE.partialObject
        [ ( "version", version |> Maybe.map JsonE.int )
        , ( "name", name |> Maybe.map JsonE.string )
        , ( "cover", cover |> Maybe.map JsonE.string )
        , ( "igdbId", igdbId |> Maybe.map JsonE.string )
        , ( "started", started |> Maybe.map (Maybe.map Date.encode >> Maybe.withDefault JsonE.null) )
        , ( "finished", finished |> Maybe.map (Maybe.map Date.encode >> Maybe.withDefault JsonE.null) )
        ]


type Msg
    = Load Game.Id (RemoteData.Response Game)
    | Reset
    | IgdbLoad String
    | IgdbSet String String
    | ChangeId String
    | ChangeName String
    | CoverMsg Uploader.Msg
    | ChangeIgdbId String
    | ChangeStart String
    | ChangeFinish String
