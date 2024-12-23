module Jasb.Gacha.Context exposing (loadContextIfNeeded)

import Jasb.Api as Api
import Jasb.Api.Data as Api
import Jasb.Api.Path as Api
import Jasb.Gacha.Context.Model exposing (..)
import Jasb.Messages as Global
import Jasb.Page.Gacha.Model as Gacha


loadContextIfNeeded : String -> Context -> ( Context, Cmd Global.Msg )
loadContextIfNeeded origin context =
    { path = Api.Context |> Api.Gacha
    , wrap = Gacha.LoadContext >> Global.GachaMsg
    , decoder = contextDecoder
    }
        |> Api.get origin
        |> Api.getDataIfNeeded context
