module Jasb.Editing.UserSelector exposing
    ( Model
    , Msg(..)
    , deselect
    , init
    , initFromExisting
    , update
    , view
    )

import AssocList
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Jasb.Api as Api
import Jasb.Api.Data as Api
import Jasb.Api.Model as Api
import Jasb.Api.Path as Api
import Jasb.User as User
import Jasb.User.Model as User
import Json.Decode as JsonD
import Material.Chips.Input as InputChip
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


type ExecutionType
    = IfStableOn Int
    | Always


type Msg
    = SetQuery String
    | Select User.Id
    | Deselect
    | ExecuteSearch ExecutionType
    | UpdateOptions (Api.Response (AssocList.Dict User.Id User.Summary))


type alias Model =
    { query : String
    , selected : Maybe User.SummaryWithId
    , queryChangeIndex : Int
    , options : Api.Data (AssocList.Dict User.Id User.Summary)
    }


optionsDecoder : JsonD.Decoder (AssocList.Dict User.Id User.Summary)
optionsDecoder =
    JsonD.assocListFromTupleList User.idDecoder User.summaryDecoder


init : Model
init =
    { query = ""
    , selected = Nothing
    , queryChangeIndex = 0
    , options = Api.initData
    }


initFromExisting : User.SummaryWithId -> Model
initFromExisting user =
    { query = ""
    , selected = Just user
    , queryChangeIndex = 0
    , options = Api.initData
    }


deselect : Model -> Model
deselect model =
    { model
        | query = ""
        , selected = Nothing
        , options = Api.initData
    }


queryIsLongEnough : String -> Bool
queryIsLongEnough query =
    String.length query >= 3


update : (Msg -> msg) -> Parent a -> Msg -> Model -> ( Model, Cmd msg )
update wrap { origin } msg model =
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

        Select user ->
            let
                fromOptions options =
                    options |> AssocList.get user |> Maybe.map (User.SummaryWithId user)

                selected =
                    model.options
                        |> Api.dataToMaybe
                        |> Maybe.andThen fromOptions
            in
            ( { model | selected = selected, query = "", options = Api.initData }
            , Cmd.none
            )

        Deselect ->
            ( { model | selected = Nothing, query = "", options = Api.initData }
            , Cmd.none
            )

        ExecuteSearch executionType ->
            if queryIsLongEnough model.query then
                let
                    doSearch () =
                        let
                            ( state, cmd ) =
                                { path = Api.UserSearch model.query
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


viewOptions : (Msg -> msg) -> String -> AssocList.Dict User.Id User.Summary -> List (Html msg)
viewOptions wrap anchorId options =
    let
        viewOption ( id, user ) =
            Menu.item [ user |> User.nameString |> Html.text ]
                |> Menu.button (Select id |> wrap |> Just)
                |> Menu.start [ User.viewAvatar user ]
                |> Menu.itemToChild

        rendered =
            if AssocList.size options > 0 then
                options |> AssocList.toList |> List.map viewOption

            else
                [ Menu.item [ Html.text "No users found." ]
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


view : (Msg -> msg) -> String -> Bool -> Model -> Html msg
view wrap idSuffix required { query, selected, options } =
    let
        id =
            "user-editor-search" ++ idSuffix

        onKeyDown key =
            case key of
                "Enter" ->
                    ExecuteSearch Always |> wrap |> JsonD.succeed

                _ ->
                    JsonD.fail "Not a monitored key."

        renderedSelected =
            case selected of
                Just { user } ->
                    [ InputChip.chip (User.nameString user) (Deselect |> wrap |> Just)
                        |> InputChip.icon [ User.viewAvatar user ] True
                        |> InputChip.attrs [ HtmlA.class "selected" ]
                        |> InputChip.view
                    ]

                Nothing ->
                    [ Icon.view Icon.circleUser ]

        error =
            if required && selected == Nothing then
                Just "You must select a user."

            else
                Nothing

        queryEditor =
            Html.div [ HtmlA.id id, HtmlA.class "search" ]
                [ TextField.outlined "User Search"
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
                    |> TextField.required required
                    |> TextField.error error
                    |> TextField.leadingIcon renderedSelected
                    |> TextField.view
                ]

        renderedOptions =
            options |> Api.viewData Api.viewOrNothing (viewOptions wrap id)
    in
    queryEditor
        :: renderedOptions
        |> Html.div
            [ HtmlA.classList
                [ ( "user-selector", True )
                , ( "selected", selected /= Nothing )
                , ( "required", required )
                ]
            ]
