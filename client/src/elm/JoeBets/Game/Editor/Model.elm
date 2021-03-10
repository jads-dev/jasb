module JoeBets.Game.Editor.Model exposing
    ( Model
    , Msg(..)
    )

import JoeBets.Game.Model as Game exposing (Game)
import JoeBets.Page.Edit.DateTime as DateTime exposing (DateTime)
import Util.RemoteData as RemoteData exposing (RemoteData)


type alias Model =
    { source : Maybe ( Game.Id, RemoteData Game )
    , name : String
    , cover : String
    , bets : Int
    , start : DateTime
    , finish : DateTime
    }


type Msg
    = Load Game.Id (RemoteData.Response Game)
    | Reset
    | ChangeName String
    | ChangeCover String
    | ChangeStart DateTime.Change
    | ChangeFinish DateTime.Change
