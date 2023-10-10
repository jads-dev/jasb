module JoeBets.Page.Gacha.Edit.CardType.RaritySelector exposing
    ( selector
    , selectorFiltered
    , validator
    )

import AssocList
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Editing.Validator as Validator exposing (Validator)
import JoeBets.Gacha.Context.Model as Gacha
import JoeBets.Gacha.Rarity as Rarity
import Material.Select as Select
import Util.Maybe as Maybe


validator : Gacha.Context -> Validator (Maybe Rarity.Id)
validator context =
    let
        rarities =
            Gacha.raritiesFromContext context

        doesNotExist id =
            (rarities |> AssocList.get id) == Nothing

        when maybeRarity =
            case maybeRarity of
                Just rarity ->
                    Validator.fromPredicate "The chosen rarity must exist." (\_ -> doesNotExist rarity)

                Nothing ->
                    Validator.fromPredicate "A rarity must be selected." ((==) Nothing)
    in
    Validator.dependent when


selector : Gacha.Context -> Maybe (Maybe Rarity.Id -> msg) -> Maybe Rarity.Id -> Html msg
selector context =
    context |> Gacha.raritiesFromContext |> selectorFiltered


selectorFiltered : Rarity.Rarities -> Maybe (Maybe Rarity.Id -> msg) -> Maybe Rarity.Id -> Html msg
selectorFiltered rarities select selected =
    let
        selectFunction =
            if AssocList.isEmpty rarities then
                Nothing

            else
                let
                    ifValid selectRarity string =
                        let
                            idIfValid given =
                                if AssocList.member given rarities then
                                    Just given

                                else
                                    Nothing
                        in
                        Rarity.idFromString string
                            |> idIfValid
                            |> selectRarity
                in
                select |> Maybe.map ifValid

        option ( id, { name } ) =
            Select.option [ Html.text name ] (Rarity.idToString id)
    in
    [ rarities
        |> AssocList.toList
        |> List.map option
        |> Select.outlined "Rarity" selectFunction (selected |> Maybe.map Rarity.idToString)
        |> Select.required True
        |> Select.fixed
        |> Select.error ("You must select a rarity." |> Maybe.when (selected == Nothing))
        |> Select.view
    ]
        |> Html.div [ HtmlA.class "inline" ]
