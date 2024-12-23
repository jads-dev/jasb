module Jasb.User.Permission.Selector exposing
    ( clear
    , selector
    , updateSelector
    )

import AssocList
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Jasb.Api as Api
import Jasb.Api.Data as Api
import Jasb.Api.Path as Api
import Jasb.Game.Id as Game
import Jasb.Game.Model as Game
import Jasb.User.Permission as Permission exposing (Permission)
import Jasb.User.Permission.Selector.Model exposing (..)
import Json.Decode as JsonD
import Material.IconButton as IconButton
import Material.Menu as Menu
import Material.TextField as TextField
import Process
import Task
import Time.Model as Time
import Util.Json.Decode as JsonD
import Util.Maybe as Maybe


type alias Parent a =
    { a
        | origin : String
        , time : Time.Context
    }


optionsDecoder : JsonD.Decoder (AssocList.Dict Game.Id Game.Summary)
optionsDecoder =
    JsonD.assocListFromTupleList Game.idDecoder Game.summaryDecoder


queryIsLongEnough : String -> Bool
queryIsLongEnough query =
    String.length query >= 3


updateSelector : (SelectorMsg -> msg) -> Parent a -> SelectorMsg -> Selector -> ( Selector, Cmd msg )
updateSelector wrap { origin } msg model =
    case msg of
        SetQuery query ->
            let
                queryChangeIndexAfter =
                    model.queryChangeIndex + 1

                executeIfStable () =
                    IfStableOn queryChangeIndexAfter |> ExecuteSearch |> wrap

                cmd =
                    if queryIsLongEnough query then
                        Process.sleep 200 |> Task.perform executeIfStable

                    else
                        Cmd.none
            in
            ( { model | query = query, queryChangeIndex = queryChangeIndexAfter }
            , cmd
            )

        ExecuteSearch executionType ->
            if queryIsLongEnough model.query then
                let
                    doSearch () =
                        let
                            ( state, cmd ) =
                                { path = Api.GameSearch model.query
                                , wrap = UpdateOptions >> wrap
                                , decoder = optionsDecoder
                                }
                                    |> Api.get origin
                                    |> Api.getData model.options
                        in
                        ( { model | options = state }
                        , cmd
                        )
                in
                case executionType of
                    IfStableOn queryChangeIndex ->
                        if model.queryChangeIndex == queryChangeIndex then
                            doSearch ()

                        else
                            ( model, Cmd.none )

                    Always ->
                        doSearch ()

            else
                ( model, Cmd.none )

        UpdateOptions response ->
            ( { model | options = model.options |> Api.updateData response }
            , Cmd.none
            )


clear : Selector -> Selector
clear model =
    { model | query = "" }


viewOptions : (Permission -> msg) -> String -> List Permission -> AssocList.Dict Game.Id Game.Summary -> List (Html msg)
viewOptions select anchorId existing options =
    let
        viewOption permission =
            let
                ( icon, name ) =
                    Permission.iconAndName permission
            in
            Menu.item [ Html.text name ]
                |> Menu.start [ icon ]
                |> Menu.button
                    (select permission |> Just)
                |> Menu.itemToChild

        toPermissions ( id, game ) =
            let
                notInExisting perm =
                    existing |> List.member perm |> not
            in
            Permission.possibleForGame id game.name |> List.filter notInExisting

        rendered =
            if AssocList.size options > 0 then
                options
                    |> AssocList.toList
                    |> List.concatMap toPermissions
                    |> List.map viewOption

            else
                [ Menu.item [ Html.text "No new permissions found." ]
                    |> Menu.start [ Icon.view Icon.ghost ]
                    |> Menu.itemToChild
                ]
    in
    [ rendered
        |> Menu.menu anchorId True
        |> Menu.defaultFocus Menu.None
        |> Menu.fixed
        |> Menu.attrs [ HtmlA.class "options" ]
        |> Menu.view
    ]


selector : (SelectorMsg -> msg) -> (Permission -> msg) -> String -> List Permission -> Selector -> Html msg
selector wrap select idSuffix existing { query, options } =
    let
        id =
            "permission-selector-search" ++ idSuffix

        onKeyDown key =
            case key of
                "Enter" ->
                    ExecuteSearch Always |> wrap |> JsonD.succeed

                _ ->
                    JsonD.fail "Not a monitored key."

        queryEditor =
            Html.div [ HtmlA.id id, HtmlA.class "search" ]
                [ TextField.outlined "Permission Search"
                    (SetQuery >> wrap |> Just)
                    query
                    |> TextField.search
                    |> TextField.keyPressAction onKeyDown
                    |> TextField.trailingIcon
                        [ IconButton.icon (Icon.magnifyingGlass |> Icon.view)
                            "Search"
                            |> IconButton.button
                                (ExecuteSearch Always
                                    |> wrap
                                    |> Maybe.when (queryIsLongEnough query)
                                )
                            |> IconButton.view
                        ]
                    |> TextField.view
                ]

        renderedOptions =
            options |> Api.viewData Api.viewOrNothing (viewOptions select id existing)
    in
    queryEditor
        :: renderedOptions
        |> Html.div [ HtmlA.class "permission-selector" ]
