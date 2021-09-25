module JoeBets.Page.User exposing
    ( init
    , load
    , update
    , view
    )

import AssocList
import Browser.Navigation as Navigation
import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Http
import JoeBets.Api as Api
import JoeBets.Coins as Coins
import JoeBets.Game.Model as Game
import JoeBets.Page exposing (Page)
import JoeBets.Page.User.Model exposing (..)
import JoeBets.Route as Route
import JoeBets.User as User
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Model as User
import Json.Decode as JsonD
import Json.Encode as JsonE
import Material.Button as Button
import Material.Switch as Switch
import Time.Model as Time
import Util.AssocList as AssocList
import Util.Maybe as Maybe
import Util.RemoteData as RemoteData


type alias Parent a =
    { a
        | user : Model
        , auth : Auth.Model
        , navigationKey : Navigation.Key
        , origin : String
        , time : Time.Context
    }


init : Model
init =
    { id = Nothing
    , user = RemoteData.Missing
    , bets = RemoteData.Missing
    , bankruptcyOverlay = Nothing
    , permissionsOverlay = Nothing
    }


load : (Msg -> msg) -> Maybe User.Id -> Parent a -> ( Parent a, Cmd msg )
load wrap userId ({ user, origin } as model) =
    let
        newModel =
            if user.id /= userId then
                { model | user = { user | id = userId, user = RemoteData.Missing, bets = RemoteData.Missing } }

            else
                model
    in
    ( newModel
    , Api.get model.origin
        { path = userId |> Maybe.map (\id -> Api.User id Api.UserRoot) |> Maybe.withDefault Api.Users
        , expect = Http.expectJson (Load >> wrap) User.withIdDecoder
        }
        :: (userId |> Maybe.map (loadBets wrap origin) |> Maybe.toList)
        |> Cmd.batch
    )


update : (Msg -> msg) -> Msg -> Parent a -> ( Parent a, Cmd msg )
update wrap msg ({ user, auth } as model) =
    case msg of
        Load result ->
            case result of
                Ok userData ->
                    let
                        newUser =
                            { user
                                | id = Just userData.id
                                , user = RemoteData.Loaded userData.user
                                , bankruptcyOverlay = Nothing
                            }

                        cmd =
                            if newUser.id /= user.id then
                                Route.pushUrl model.navigationKey (Route.User newUser.id)

                            else
                                Cmd.none

                        newAuth =
                            if Just userData.id == (auth.localUser |> Maybe.map .id) then
                                { auth | localUser = Just userData }

                            else
                                auth
                    in
                    ( { model | user = newUser, auth = newAuth }, cmd )

                Err error ->
                    ( { model | user = { user | user = RemoteData.Failed error } }, Cmd.none )

        LoadBets userId result ->
            if Just userId == user.id then
                case result of
                    Ok userBets ->
                        ( { model | user = { user | bets = RemoteData.Loaded userBets } }, Cmd.none )

                    Err error ->
                        ( { model | user = { user | bets = RemoteData.Failed error } }, Cmd.none )

            else
                ( model, Cmd.none )

        SetBankruptcyToggle enabled ->
            let
                updateOverlay overlay =
                    { overlay | sureToggle = enabled }
            in
            ( { model | user = { user | bankruptcyOverlay = user.bankruptcyOverlay |> Maybe.map updateOverlay } }
            , Cmd.none
            )

        GoBankrupt ->
            case user.id of
                Just uid ->
                    ( model
                    , Api.post model.origin
                        { path = Api.User uid Api.Bankrupt
                        , body = Http.emptyBody
                        , expect = Http.expectJson (Load >> wrap) User.withIdDecoder
                        }
                    )

                Nothing ->
                    ( model, Cmd.none )

        ToggleBankruptcyOverlay show ->
            case user.id of
                Just uid ->
                    let
                        bankruptcyOverlay =
                            if show then
                                Just
                                    { sureToggle = False
                                    , stats = RemoteData.Missing
                                    }

                            else
                                Nothing
                    in
                    ( { model | user = { user | bankruptcyOverlay = bankruptcyOverlay } }
                    , loadBankruptcyStats wrap model.origin uid
                    )

                Nothing ->
                    ( model, Cmd.none )

        LoadBankruptcyStats id result ->
            if user.id == Just id then
                let
                    updateOverlay overlay =
                        { overlay | stats = RemoteData.load result }
                in
                ( { model | user = { user | bankruptcyOverlay = user.bankruptcyOverlay |> Maybe.map updateOverlay } }
                , Cmd.none
                )

            else
                ( model, Cmd.none )

        TogglePermissionsOverlay show ->
            case user.id of
                Just uid ->
                    let
                        permissionsOverlay =
                            if show then
                                Just
                                    { permissions = RemoteData.Missing }

                            else
                                Nothing
                    in
                    ( { model | user = { user | permissionsOverlay = permissionsOverlay } }
                    , loadPermissions wrap model.origin uid
                    )

                Nothing ->
                    ( model, Cmd.none )

        LoadPermissions userId response ->
            if user.id == Just userId then
                let
                    updatePermissions overlay =
                        { overlay | permissions = response |> Result.map (AssocList.fromListWithDerivedKey .gameId) |> RemoteData.load }
                in
                ( { model | user = { user | permissionsOverlay = user.permissionsOverlay |> Maybe.map updatePermissions } }, Cmd.none )

            else
                ( model, Cmd.none )

        SetPermissions userId gameId permissions ->
            if user.id == Just userId then
                let
                    replacePermissions =
                        AssocList.update gameId (Maybe.map (\old -> { old | permissions = permissions }))

                    updatePermissions overlay =
                        { overlay | permissions = overlay.permissions |> RemoteData.map replacePermissions }
                in
                ( { model | user = { user | permissionsOverlay = user.permissionsOverlay |> Maybe.map updatePermissions } }
                , setPermissions wrap model.origin userId gameId permissions
                )

            else
                ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


view : (Msg -> msg) -> Parent a -> Page msg
view wrap model =
    let
        { id, user, bankruptcyOverlay, permissionsOverlay } =
            model.user

        isLocal =
            id == (model.auth.localUser |> Maybe.map .id)

        body userData =
            let
                avatar =
                    case id of
                        Just givenId ->
                            User.viewAvatar givenId userData

                        Nothing ->
                            Html.text ""

                isYou =
                    if isLocal then
                        [ Html.span [ HtmlA.class "local-user-indicator" ] [ Html.text " (you)" ] ]

                    else
                        []

                identity =
                    [ [ avatar, User.viewName userData ], isYou ]

                adminControls =
                    if Auth.isAdmin model.auth.localUser then
                        case id of
                            Just givenId ->
                                [ [ Html.div []
                                        [ Button.view Button.Raised
                                            Button.Padded
                                            "Edit Permissions"
                                            (Icon.userCog |> Icon.present |> Icon.view |> Just)
                                            (TogglePermissionsOverlay True |> wrap |> Just)
                                        ]
                                  ]
                                , permissionsOverlay |> Maybe.map (viewPermissionsOverlay wrap givenId) |> Maybe.withDefault []
                                ]
                                    |> List.concat

                            Nothing ->
                                []

                    else
                        []

                bankruptcyControls =
                    if isLocal then
                        [ [ Html.div [ HtmlA.class "bankrupt dangerous" ]
                                [ Html.p [] [ Html.text "Going bankrupt will reset your balance to the starting amount, and cancel all your current bets." ]
                                , Button.view Button.Raised
                                    Button.Padded
                                    "Go Bankrupt"
                                    (Icon.recycle |> Icon.present |> Icon.view |> Just)
                                    (ToggleBankruptcyOverlay True |> wrap |> Just)
                                ]
                          ]
                        , bankruptcyOverlay |> Maybe.map (viewBankruptcyOverlay wrap) |> Maybe.withDefault []
                        ]
                            |> List.concat

                    else
                        []

                controls =
                    List.concat [ bankruptcyControls, adminControls ]

                netWorthEntry ( name, amount ) =
                    Html.li []
                        [ Html.span [ HtmlA.class "title" ] [ Html.text name ]
                        , Coins.view amount
                        ]

                netWorth =
                    [ ( "Net Worth", userData.balance + userData.betValue )
                    , ( "Balance", userData.balance )
                    , ( "Bets", userData.betValue )
                    ]

                contents =
                    [ [ identity |> List.concat |> Html.div [ HtmlA.class "identity" ]
                      , netWorth |> List.map netWorthEntry |> Html.ul [ HtmlA.class "net-worth" ]
                      ]
                    , controls
                    ]
            in
            contents |> List.concat

        title =
            case user |> RemoteData.toMaybe of
                Just u ->
                    "“" ++ u.name ++ "”"

                Nothing ->
                    "Profile"
    in
    { title = "User " ++ title
    , id = "user"
    , body = user |> RemoteData.view body
    }


viewBankruptcyOverlay : (Msg -> msg) -> BankruptcyOverlay -> List (Html msg)
viewBankruptcyOverlay wrap { sureToggle, stats } =
    let
        viewStats { amountLost, stakesLost, lockedAmountLost, lockedStakesLost, balanceAfter } =
            [ Html.p []
                [ Html.text "You will lose "
                , stakesLost |> String.fromInt |> Html.text
                , Html.text " bets you have made (totaling "
                , amountLost |> Coins.view
                , Html.text "), "
                , lockedStakesLost |> String.fromInt |> Html.text
                , Html.text " ("
                , lockedAmountLost |> Coins.view
                , Html.text ") of which are now locked and therefore not possible to place again."
                ]
            , Html.p []
                [ Html.text "Once bankrupt, you will be given "
                , balanceAfter |> Coins.view
                , Html.text "."
                ]
            ]

        renderedStats =
            stats |> RemoteData.view viewStats

        controls =
            [ Html.div [ HtmlA.class "dangerous" ]
                [ Switch.view (Html.text "I am sure I want to do this.")
                    sureToggle
                    (SetBankruptcyToggle >> wrap |> Just)
                ]
            , Html.div [ HtmlA.class "actions" ]
                [ Button.view Button.Standard
                    Button.Padded
                    "Cancel"
                    (Icon.times |> Icon.present |> Icon.view |> Just)
                    (ToggleBankruptcyOverlay False |> wrap |> Just)
                , Html.div [ HtmlA.class "dangerous" ]
                    [ Button.view
                        Button.Raised
                        Button.Padded
                        "Go Bankrupt"
                        (Icon.recycle |> Icon.present |> Icon.view |> Just)
                        (GoBankrupt |> wrap |> Maybe.when sureToggle)
                    ]
                ]
            ]
    in
    [ Html.div [ HtmlA.class "overlay" ]
        [ [ renderedStats, controls ] |> List.concat |> Html.div [ HtmlA.id "bankruptcy-overlay" ]
        ]
    ]


viewPermissionsOverlay : (Msg -> msg) -> User.Id -> PermissionsOverlay -> List (Html msg)
viewPermissionsOverlay wrap userId overlay =
    let
        body gamePermissions =
            [ gamePermissions |> AssocList.values |> List.map viewGamePermissions |> Html.ul [] ]

        viewGamePermissions { gameId, gameName, permissions } =
            Html.li []
                [ Html.span [] [ Html.text gameName ]
                , Html.div [] [ Switch.view (Html.text "Manage") permissions.canManageBets ((\v -> SetPermissions userId gameId { permissions | canManageBets = v } |> wrap) |> Just) ]
                ]

        alwaysBody =
            [ Button.view Button.Standard
                Button.Padded
                "Close"
                (Icon.times |> Icon.present |> Icon.view |> Just)
                (TogglePermissionsOverlay False |> wrap |> Just)
            ]
    in
    [ Html.div [ HtmlA.class "overlay" ]
        [ [ overlay.permissions |> RemoteData.view body, alwaysBody ] |> List.concat |> Html.div [ HtmlA.id "permissions-overlay" ]
        ]
    ]


loadBets : (Msg -> msg) -> String -> User.Id -> Cmd msg
loadBets wrap origin id =
    Api.get origin
        { path = Api.User id Api.UserBets
        , expect = Http.expectJson (LoadBets id >> wrap) (JsonD.list decodeUserBet)
        }


loadBankruptcyStats : (Msg -> msg) -> String -> User.Id -> Cmd msg
loadBankruptcyStats wrap origin id =
    Api.get origin
        { path = Api.User id Api.Bankrupt
        , expect = Http.expectJson (LoadBankruptcyStats id >> wrap) decodeBankruptcyStats
        }


loadPermissions : (Msg -> msg) -> String -> User.Id -> Cmd msg
loadPermissions wrap origin id =
    Api.get origin
        { path = Api.User id Api.Permissions
        , expect = Http.expectJson (LoadPermissions id >> wrap) (JsonD.list decodeGamePermissions)
        }


setPermissions : (Msg -> msg) -> String -> User.Id -> Game.Id -> Permissions -> Cmd msg
setPermissions wrap origin id gameId { canManageBets } =
    Api.post origin
        { path = Api.User id Api.Permissions
        , body = JsonE.object [ ( "game", gameId |> Game.encodeId ), ( "canManageBets", canManageBets |> JsonE.bool ) ] |> Http.jsonBody
        , expect = NoOp |> wrap |> always |> Http.expectWhatever
        }
