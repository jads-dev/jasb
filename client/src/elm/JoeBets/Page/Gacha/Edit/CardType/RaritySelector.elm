module JoeBets.Page.Gacha.Edit.CardType.RaritySelector exposing
    ( selector
    , validator
    )

import AssocList
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Api.Data as Api
import JoeBets.Editing.Validator as Validator exposing (Validator)
import JoeBets.Gacha.Rarity as Rarity
import Material.Select as Select
import Util.Maybe as Maybe


validator : Rarity.Context -> Validator (Maybe Rarity.Id)
validator context =
    let
        rarities =
            context.rarities
                |> Api.dataToMaybe
                |> Maybe.withDefault AssocList.empty

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


selector : Rarity.Context -> Maybe (Maybe Rarity.Id -> msg) -> Maybe Rarity.Id -> Html msg
selector context select selected =
    let
        rarities =
            context.rarities
                |> Api.dataToMaybe
                |> Maybe.withDefault AssocList.empty

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
        |> Select.error ("You must select a rarity." |> Maybe.when (selected == Nothing))
        |> Select.view
    ]
        |> Html.div [ HtmlA.class "inline" ]
