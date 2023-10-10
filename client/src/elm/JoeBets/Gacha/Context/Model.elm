module JoeBets.Gacha.Context.Model exposing
    ( Context
    , InnerContext
    , contextDecoder
    , qualitiesFromContext
    , qualityFromContext
    , raritiesFromContext
    , rarityFromContext
    )

import AssocList
import JoeBets.Api.Data as Api
import JoeBets.Gacha.Quality as Quality exposing (Quality)
import JoeBets.Gacha.Rarity as Rarity exposing (Rarity)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD


type alias Context =
    Api.Data InnerContext


type alias InnerContext =
    { rarities : Rarity.Rarities
    , qualities : Quality.Qualities
    }


contextDecoder : JsonD.Decoder InnerContext
contextDecoder =
    JsonD.succeed InnerContext
        |> JsonD.required "rarities" Rarity.raritiesDecoder
        |> JsonD.required "qualities" Quality.qualitiesDecoder


rarityFromContext : Context -> Rarity.Id -> Maybe Rarity
rarityFromContext context id =
    context |> Api.dataToMaybe |> Maybe.andThen (.rarities >> AssocList.get id)


raritiesFromContext : Context -> Rarity.Rarities
raritiesFromContext context =
    context |> Api.dataToMaybe |> Maybe.map .rarities |> Maybe.withDefault AssocList.empty


qualityFromContext : Context -> Quality.Id -> Maybe Quality
qualityFromContext context id =
    context |> Api.dataToMaybe |> Maybe.andThen (.qualities >> AssocList.get id)


qualitiesFromContext : Context -> Quality.Qualities
qualitiesFromContext context =
    context |> Api.dataToMaybe |> Maybe.map .qualities |> Maybe.withDefault AssocList.empty
