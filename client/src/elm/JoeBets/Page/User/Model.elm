module JoeBets.Page.User.Model exposing
    ( Model
    , Msg(..)
    )

import Http
import JoeBets.User.Model as User exposing (User)
import Util.RemoteData exposing (RemoteData)


type alias Model =
    { id : Maybe User.Id
    , user : RemoteData User
    , bankruptcyToggle : Bool
    }


type Msg
    = Load (Result Http.Error User.WithId)
    | SetBankruptcyToggle Bool
    | GoBankrupt
