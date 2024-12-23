module Jasb.Page.Gacha.Forge.Model exposing
    ( ForgeResponse
    , Forged(..)
    , Model
    , Msg(..)
    , encodeForgeRequest
    , forgeRequestFromModel
    , forgeRequestValidator
    , forgeResponseDecoder
    , forgedDecoder
    , quoteValidator
    )

import Jasb.Api.Action as Api
import Jasb.Api.Data as Api
import Jasb.Api.Model as Api
import Jasb.Editing.Validator as Validator exposing (Validator)
import Jasb.Gacha.Balance as Balance exposing (Balance)
import Jasb.Gacha.CardType as CardType
import Jasb.Gacha.Rarity as Rarity
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE


type alias ForgeResponse =
    { forged : CardType.WithId
    , balance : Balance
    }


forgeResponseDecoder : JsonD.Decoder ForgeResponse
forgeResponseDecoder =
    JsonD.succeed ForgeResponse
        |> JsonD.required "forged" CardType.withIdDecoder
        |> JsonD.required "balance" Balance.decoder


type Forged
    = Forged CardType.WithId
    | Unforged Rarity.WithId


forgedDecoder : JsonD.Decoder Forged
forgedDecoder =
    JsonD.oneOf
        [ CardType.withIdDecoder |> JsonD.map Forged
        , Rarity.withIdDecoder |> JsonD.map Unforged
        ]


type Msg
    = SetQuote String
    | SetRarity (Maybe Rarity.Id)
    | Forge (Api.Process ForgeResponse)
    | ConfirmRetire (Maybe CardType.Id)
    | Retire CardType.Id (Api.Process CardType.WithId)
    | LoadExisting (Api.Response (List Forged))


type alias Model =
    { existing : Api.Data (List Forged)
    , forge : Api.ActionState
    , retire : Api.ActionState
    , quote : String
    , rarity : Maybe Rarity.Id
    , confirmRetire : Maybe CardType.Id
    }


type alias ForgeRequest =
    { quote : String, rarity : Maybe Rarity.Id }


encodeForgeRequest : ForgeRequest -> JsonE.Value
encodeForgeRequest { quote } =
    JsonE.object [ ( "quote", JsonE.string quote ) ]


forgeRequestFromModel : Model -> ForgeRequest
forgeRequestFromModel model =
    { quote = model.quote, rarity = model.rarity }


quoteValidator : Validator String
quoteValidator =
    Validator.all
        [ Validator.fromPredicate "Quote must not be empty." String.isEmpty
        , Validator.fromPredicate "Quote must be at most 100 characters."
            (\q -> String.length q > 100)
        ]


rarityValidator : Validator (Maybe Rarity.Id)
rarityValidator =
    Validator.fromPredicate "Must select a rarity." ((==) Nothing)


forgeRequestValidator : Validator ForgeRequest
forgeRequestValidator =
    Validator.all
        [ quoteValidator |> Validator.map .quote
        , rarityValidator |> Validator.map .rarity
        ]
