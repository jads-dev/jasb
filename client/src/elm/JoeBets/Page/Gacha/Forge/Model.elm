module JoeBets.Page.Gacha.Forge.Model exposing
    ( Forged(..)
    , Model
    , Msg(..)
    , encodeForgeRequest
    , forgeRequestFromModel
    , forgeRequestValidator
    , forgedDecoder
    , quoteValidator
    )

import JoeBets.Api.Action as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.Model as Api
import JoeBets.Editing.Validator as Validator exposing (Validator)
import JoeBets.Gacha.CardType as CardType
import JoeBets.Gacha.Rarity as Rarity
import Json.Decode as JsonD
import Json.Encode as JsonE


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
    | Forge (Api.Process CardType.WithId)
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
