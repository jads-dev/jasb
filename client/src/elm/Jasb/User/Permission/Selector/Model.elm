module Jasb.User.Permission.Selector.Model exposing
    ( ExecutionType(..)
    , Selector
    , SelectorMsg(..)
    , initSelector
    )

import AssocList
import Jasb.Api.Data as Api
import Jasb.Api.Model as Api
import Jasb.Game.Id as Game
import Jasb.Game.Model as Game


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
