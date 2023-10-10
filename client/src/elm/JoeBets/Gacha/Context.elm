module JoeBets.Gacha.Context exposing (loadContextIfNeeded)

import JoeBets.Api as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.Path as Api
import JoeBets.Gacha.Context.Model exposing (..)
import JoeBets.Messages as Global
import JoeBets.Page.Gacha.Model as Gacha


loadContextIfNeeded : String -> Context -> ( Context, Cmd Global.Msg )
loadContextIfNeeded origin context =
    { path = Api.Context |> Api.Gacha
    , wrap = Gacha.LoadContext >> Global.GachaMsg
    , decoder = contextDecoder
    }
        |> Api.get origin
        |> Api.getDataIfNeeded context
