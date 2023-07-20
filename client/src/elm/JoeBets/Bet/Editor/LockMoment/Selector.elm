module JoeBets.Bet.Editor.LockMoment.Selector exposing (..)

import AssocList
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Bet.Editor.LockMoment as LockMoment
import JoeBets.Bet.Editor.LockMoment.Editor as LockMoment
import Material.Attributes as Material
import Material.IconButton as IconButton
import Material.Select as Select
import Util.RemoteData as RemoteData


selector : (LockMoment.EditorMsg -> msg) -> LockMoment.Context -> Maybe LockMoment.Editor -> (Maybe LockMoment.Id -> msg) -> Maybe LockMoment.Id -> Html msg
selector wrapEditor context maybeEditor select selected =
    let
        lockMoments =
            context.lockMoments
                |> RemoteData.toMaybe
                |> Maybe.map AssocList.toList
                |> Maybe.withDefault []

        model =
            { label = "Lock Moment"
            , idToString = LockMoment.idToString
            , idFromString = LockMoment.idFromString >> Just
            , selected = selected
            , wrap = select
            , disabled = List.isEmpty lockMoments
            , fullWidth = True
            , attrs = [ Material.outlined ]
            }

        option ( id, { name } ) =
            { id = id
            , icon = Nothing
            , primary = [ Html.text name ]
            , secondary = Nothing
            , meta = Nothing
            }
    in
    (lockMoments |> List.map option |> Select.view model)
        :: IconButton.view (Icon.edit |> Icon.view) "Edit Lock Moments" (LockMoment.ShowEditor |> wrapEditor |> Just)
        :: LockMoment.viewEditor wrapEditor context maybeEditor
        |> Html.div [ HtmlA.class "inline" ]
