module JoeBets.User.Permission.Selector.Model exposing
    ( ExecutionType(..)
    , Selector
    , SelectorMsg(..)
    , initSelector
    )

import AssocList
import JoeBets.Api as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.Model as Api
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game


type ExecutionType
    = IfStableOn Int
    | Always


type SelectorMsg
    = SetQuery String
    | ExecuteSearch ExecutionType
    | UpdateOptions (Api.Response (AssocList.Dict Game.Id Game.Summary))


type alias Selector =
    { query : String
    , queryChangeIndex : Int
    , options : Api.Data (AssocList.Dict Game.Id Game.Summary)
    }


initSelector : Selector
initSelector =
    { query = ""
    , queryChangeIndex = 0
    , options = Api.initData
    }
