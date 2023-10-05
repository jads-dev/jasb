module JoeBets.User.Permission exposing
    ( BetsTarget(..)
    , Permission(..)
    , canManageBets
    , canManageGacha
    , canManageGameBets
    , canManageGames
    , canManagePermissions
    , encodeSetPermission
    , iconAndName
    , permissionsDecoder
    , possibleForGame
    , view
    , viewPermissions
    , viewSuggest
    )

import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import JoeBets.Game.Id as Game
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Material.Chips as Chips
import Material.Chips.Input as InputChip
import Material.Chips.Suggestion as SuggestionChip


type BetsTarget
    = AllBets
    | GameBets { id : Game.Id, name : String }


type Permission
    = ManageBets BetsTarget
    | ManageGames
    | ManageGacha
    | ManagePermissions


permissionsDecoder : JsonD.Decoder (List Permission)
permissionsDecoder =
    let
        allDecoder value =
            let
                fromString string =
                    if string == "*" then
                        JsonD.succeed value

                    else
                        JsonD.fail "Not a recognised permission value."
            in
            JsonD.string |> JsonD.andThen fromString

        decodeManageBets =
            let
                manageGameBets id name =
                    { id = id, name = name } |> GameBets |> ManageBets

                gameDecoder =
                    JsonD.succeed manageGameBets
                        |> JsonD.required "id" Game.idDecoder
                        |> JsonD.required "name" JsonD.string
            in
            JsonD.oneOf
                [ gameDecoder
                , allDecoder (ManageBets AllBets)
                ]
    in
    JsonD.succeed (\perms gacha games bets -> List.concat [ perms, gacha, games, bets ])
        |> JsonD.optional "managePermissions" (JsonD.list (allDecoder ManagePermissions)) []
        |> JsonD.optional "manageGacha" (JsonD.list (allDecoder ManageGacha)) []
        |> JsonD.optional "manageGames" (JsonD.list (allDecoder ManageGames)) []
        |> JsonD.optional "manageBets" (JsonD.list decodeManageBets) []


encodeSetPermission : Permission -> Bool -> JsonE.Value
encodeSetPermission permission set =
    let
        value =
            JsonE.bool set
    in
    case permission of
        ManageGames ->
            JsonE.object [ ( "manageGames", value ) ]

        ManagePermissions ->
            JsonE.object [ ( "managePermissions", value ) ]

        ManageGacha ->
            JsonE.object [ ( "manageGacha", value ) ]

        ManageBets AllBets ->
            JsonE.object [ ( "manageBets", value ) ]

        ManageBets (GameBets game) ->
            JsonE.object
                [ ( "game", Game.encodeId game.id )
                , ( "manageBets", value )
                ]


iconAndName : Permission -> ( Html msg, String )
iconAndName permission =
    case permission of
        ManageGames ->
            ( Icon.view Icon.gamepad, "All Games" )

        ManageGacha ->
            ( Icon.view Icon.diceD20, "All Gacha" )

        ManagePermissions ->
            ( Icon.view Icon.clipboardList, "All Permissions" )

        ManageBets AllBets ->
            ( Icon.view Icon.dice, "All Bets" )

        ManageBets (GameBets game) ->
            ( Icon.view Icon.dice, game.name ++ " Bets" )


view : (Permission -> Maybe msg) -> Permission -> Html msg
view removePermission permission =
    let
        ( icon, name ) =
            iconAndName permission
    in
    InputChip.chip name (removePermission permission)
        |> InputChip.icon [ icon ] False
        |> InputChip.view


viewSuggest : (Permission -> Maybe msg) -> Permission -> Html msg
viewSuggest addPermission permission =
    let
        ( icon, name ) =
            iconAndName permission
    in
    SuggestionChip.chip name
        |> SuggestionChip.button (addPermission permission)
        |> SuggestionChip.icon [ icon ]
        |> SuggestionChip.elevated
        |> SuggestionChip.view


viewPermissions : (Bool -> Permission -> msg) -> List Permission -> List Permission -> Html msg
viewPermissions set suggestions permissions =
    List.append
        (suggestions |> List.map (viewSuggest (set True >> Just)))
        (permissions |> List.map (view (set False >> Just)))
        |> Chips.set []


possibleForGame : Game.Id -> String -> List Permission
possibleForGame gameId gameName =
    [ { id = gameId, name = gameName } |> GameBets |> ManageBets ]


canManageGameBets : Game.Id -> List Permission -> Bool
canManageGameBets game permissions =
    let
        checkPermission permission =
            case permission of
                ManageBets AllBets ->
                    True

                ManageBets (GameBets { id }) ->
                    id == game

                _ ->
                    False
    in
    permissions |> List.any checkPermission


canManageBets : List Permission -> Bool
canManageBets permissions =
    let
        checkPermission permission =
            case permission of
                ManageBets AllBets ->
                    True

                _ ->
                    False
    in
    permissions |> List.any checkPermission


canManageGames : List Permission -> Bool
canManageGames permissions =
    let
        checkPermission permission =
            case permission of
                ManageGames ->
                    True

                _ ->
                    False
    in
    permissions |> List.any checkPermission


canManageGacha : List Permission -> Bool
canManageGacha permissions =
    let
        checkPermission permission =
            case permission of
                ManageGacha ->
                    True

                _ ->
                    False
    in
    permissions |> List.any checkPermission


canManagePermissions : List Permission -> Bool
canManagePermissions permissions =
    let
        checkPermission permission =
            case permission of
                ManagePermissions ->
                    True

                _ ->
                    False
    in
    permissions |> List.any checkPermission
