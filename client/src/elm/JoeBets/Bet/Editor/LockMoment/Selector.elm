module JoeBets.Bet.Editor.LockMoment.Selector exposing (selector)

import AssocList
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Api.Data as Api
import JoeBets.Bet.Editor.LockMoment as LockMoment
import JoeBets.Bet.Editor.LockMoment.Editor as LockMoment
import Material.IconButton as IconButton
import Material.Select as Select
import Util.Maybe as Maybe


selector : Maybe (LockMoment.EditorMsg -> msg) -> LockMoment.Context -> Maybe (Maybe LockMoment.Id -> msg) -> Maybe LockMoment.Id -> Html msg
selector wrapEditor context select selected =
    let
        lockMoments =
            context.lockMoments
                |> Api.dataToMaybe
                |> Maybe.withDefault AssocList.empty

        wrapIfGiven value =
            wrapEditor |> Maybe.map (\w -> value |> w)

        option ( id, { name } ) =
            Select.option [ Html.text name ] (LockMoment.idToString id)

        selectFunction =
            if AssocList.isEmpty lockMoments then
                Nothing

            else
                let
                    ifValid selectLockMoment string =
                        let
                            potentialId =
                                LockMoment.idFromString string

                            idIfValid =
                                if AssocList.member potentialId lockMoments then
                                    Just potentialId

                                else
                                    Nothing
                        in
                        selectLockMoment idIfValid
                in
                select |> Maybe.map ifValid
    in
    [ lockMoments
        |> AssocList.toList
        |> List.map option
        |> Select.outlined "Lock Moment" selectFunction (selected |> Maybe.map LockMoment.idToString)
        |> Select.supportingText "The moment at which people can no longer change bets."
        |> Select.error ("You must select a lock moment." |> Maybe.when (selected == Nothing))
        |> Select.required True
        |> Select.view
    , IconButton.icon (Icon.edit |> Icon.view)
        "Edit Lock Moments"
        |> IconButton.button (LockMoment.ShowEditor |> wrapIfGiven)
        |> IconButton.view
    ]
        |> Html.div [ HtmlA.class "inline" ]
