module JoeBets.Page.User exposing
    ( init
    , load
    , update
    , view
    )

import AssocList
import Browser.Navigation as Navigation
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Events as HtmlE
import Http
import JoeBets.Api as Api
import JoeBets.Bet as Bet
import JoeBets.Coins as Coins
import JoeBets.Game as Game
import JoeBets.Game.Id as Game
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
import Util.Html.Events as HtmlE
import Util.Json.Decode as JsonD
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
    Nothing


initFromId : User.Id -> UserModel
initFromId id =
    { id = id
    , user = RemoteData.Missing
    , bets = RemoteData.Missing
    , bankruptcyOverlay = Nothing
    , permissionsOverlay = Nothing
    }


load : (Msg -> msg) -> Maybe User.Id -> Parent a -> ( Parent a, Cmd msg )
load wrap userId ({ user } as model) =
    let
        newModel =
            if (user |> Maybe.map .id) /= userId then
                { model | user = userId |> Maybe.map initFromId }

            else
                model
    in
    ( newModel
    , Api.get model.origin
        { path = userId |> Maybe.map (\id -> Api.User id Api.UserRoot) |> Maybe.withDefault Api.Users
        , expect = Http.expectJson (Load >> wrap) User.withIdDecoder
        }
    )


update : (Msg -> msg) -> Msg -> Parent a -> ( Parent a, Cmd msg )
update wrap msg ({ user, auth, origin } as model) =
    case msg of
        Load result ->
            case result of
                Ok userData ->
                    let
                        newUser =
                            { id = userData.id
                            , user = RemoteData.Loaded userData.user
                            , bets = RemoteData.Missing
                            , bankruptcyOverlay = Nothing
                            , permissionsOverlay = Nothing
                            }

                        cmd =
                            if Just newUser.id /= (user |> Maybe.map .id) then
                                newUser.id |> Just |> Route.User |> Route.pushUrl model.navigationKey

                            else
                                Cmd.none

                        newAuth =
                            if Just userData.id == (auth.localUser |> Maybe.map .id) then
                                { auth | localUser = Just userData }

                            else
                                auth
                    in
                    ( { model | user = Just newUser, auth = newAuth }, cmd )

                Err error ->
                    ( { model | user = user |> Maybe.map (\u -> { u | user = RemoteData.Failed error }) }
                    , Cmd.none
                    )

        TryLoadBets userId ->
            let
                cmd =
                    case user of
                        Just givenUser ->
                            if givenUser.id == userId && givenUser.bets == RemoteData.Missing then
                                loadBets wrap origin userId

                            else
                                Cmd.none

                        Nothing ->
                            Cmd.none
            in
            ( model, cmd )

        LoadBets userId result ->
            let
                updateUser givenUser =
                    if userId == givenUser.id then
                        { givenUser | bets = RemoteData.load result }

                    else
                        givenUser
            in
            ( { model | user = user |> Maybe.map updateUser }, Cmd.none )

        SetBankruptcyToggle enabled ->
            let
                updateUser givenUser =
                    { givenUser | bankruptcyOverlay = givenUser.bankruptcyOverlay |> Maybe.map updateOverlay }

                updateOverlay overlay =
                    { overlay | sureToggle = enabled }
            in
            ( { model | user = user |> Maybe.map updateUser }, Cmd.none )

        GoBankrupt ->
            case user |> Maybe.map .id of
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
            case user of
                Just givenUser ->
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
                    ( { model | user = Just { givenUser | bankruptcyOverlay = bankruptcyOverlay } }
                    , loadBankruptcyStats wrap model.origin givenUser.id
                    )

                Nothing ->
                    ( model, Cmd.none )

        LoadBankruptcyStats id result ->
            case user of
                Just givenUser ->
                    if givenUser.id == id then
                        let
                            updateOverlay overlay =
                                { overlay | stats = RemoteData.load result }

                            newOverlay =
                                givenUser.bankruptcyOverlay |> Maybe.map updateOverlay
                        in
                        ( { model | user = Just { givenUser | bankruptcyOverlay = newOverlay } }
                        , Cmd.none
                        )

                    else
                        ( model, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        TogglePermissionsOverlay show ->
            case user of
                Just givenUser ->
                    let
                        permissionsOverlay =
                            if show then
                                Just
                                    { permissions = RemoteData.Missing }

                            else
                                Nothing
                    in
                    ( { model | user = Just { givenUser | permissionsOverlay = permissionsOverlay } }
                    , loadPermissions wrap model.origin givenUser.id
                    )

                Nothing ->
                    ( model, Cmd.none )

        LoadPermissions userId response ->
            case user of
                Just givenUser ->
                    if givenUser.id == userId then
                        let
                            updatePermissions overlay =
                                { overlay | permissions = response |> Result.map (AssocList.fromListWithDerivedKey .gameId) |> RemoteData.load }

                            newOverlay =
                                givenUser.permissionsOverlay |> Maybe.map updatePermissions
                        in
                        ( { model | user = Just { givenUser | permissionsOverlay = newOverlay } }, Cmd.none )

                    else
                        ( model, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        SetPermissions userId gameId permissions ->
            case user of
                Just givenUser ->
                    if givenUser.id == userId then
                        let
                            replacePermissions =
                                AssocList.update gameId (Maybe.map (\old -> { old | permissions = permissions }))

                            updatePermissions overlay =
                                { overlay | permissions = overlay.permissions |> RemoteData.map replacePermissions }

                            newOverlay =
                                givenUser.permissionsOverlay |> Maybe.map updatePermissions
                        in
                        ( { model | user = Just { givenUser | permissionsOverlay = newOverlay } }
                        , setPermissions wrap model.origin userId gameId permissions
                        )

                    else
                        ( model, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


view : (Msg -> msg) -> Parent a -> Page msg
view wrap model =
    case model.user of
        Just { id, user, bets, bankruptcyOverlay, permissionsOverlay } ->
            let
                isLocal =
                    Just id == (model.auth.localUser |> Maybe.map .id)

                title =
                    case user |> RemoteData.toMaybe of
                        Just u ->
                            "“" ++ u.name ++ "”"

                        Nothing ->
                            "Profile"

                body userData =
                    let
                        avatar =
                            User.viewAvatar id userData

                        isYou =
                            if isLocal then
                                [ Html.span [ HtmlA.class "local-user-indicator" ] [ Html.text " (you)" ] ]

                            else
                                []

                        identity =
                            [ [ avatar, User.viewName userData ], isYou ]

                        adminControls =
                            if Auth.isAdmin model.auth.localUser then
                                [ [ Html.div []
                                        [ Button.view Button.Raised
                                            Button.Padded
                                            "Edit Permissions"
                                            (Icon.userCog |> Icon.view |> Just)
                                            (TogglePermissionsOverlay True |> wrap |> Just)
                                        ]
                                  ]
                                , permissionsOverlay |> Maybe.map (viewPermissionsOverlay wrap id) |> Maybe.withDefault []
                                ]
                                    |> List.concat

                            else
                                []

                        bankruptcyControls =
                            if isLocal then
                                [ [ Html.div [ HtmlA.class "bankrupt dangerous" ]
                                        [ Html.p [] [ Html.text "Going bankrupt will reset your balance to the starting amount, and cancel all your current bets." ]
                                        , Button.view Button.Raised
                                            Button.Padded
                                            "Go Bankrupt"
                                            (Icon.recycle |> Icon.view |> Just)
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

                        betsSection =
                            [ Html.details [ HtmlA.class "bets", TryLoadBets id |> wrap |> always |> HtmlE.onToggle ]
                                [ Html.summary [] [ Html.h3 [] [ Html.text "Bets" ] ]
                                , Html.div [] (RemoteData.view (viewBets model.time id) bets)
                                ]
                            ]

                        contents =
                            [ [ Html.h2 [] [ Html.text title ]
                              , identity |> List.concat |> Html.div [ HtmlA.class "identity" ]
                              , netWorth |> List.map netWorthEntry |> Html.ul [ HtmlA.class "net-worth" ]
                              ]
                            , betsSection
                            , controls
                            ]
                    in
                    contents |> List.concat
            in
            { title = "User " ++ title
            , id = "user"
            , body = user |> RemoteData.view body
            }

        Nothing ->
            { title = "User Profile"
            , id = "user"
            , body = RemoteData.view (always []) RemoteData.Missing
            }


viewBets : Time.Context -> User.Id -> AssocList.Dict Game.Id Game.WithBets -> List (Html msg)
viewBets time userId =
    let
        viewBet gameId game ( id, bet ) =
            Html.li [] [ Bet.viewSummarised time Nothing (Just userId) gameId game.name id bet ]

        viewGame ( id, { game, bets } ) =
            Html.li []
                [ Html.details []
                    [ Html.summary [] [ Html.h4 [] [ Html.text game.name ] ]
                    , bets
                        |> AssocList.toList
                        |> List.map (viewBet id game)
                        |> Html.ul [ HtmlA.class "bets-section" ]
                    ]
                ]
    in
    AssocList.toList >> List.map viewGame >> Html.ul [ HtmlA.class "game-section" ] >> List.singleton


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
                    (Icon.times |> Icon.view |> Just)
                    (ToggleBankruptcyOverlay False |> wrap |> Just)
                , Html.div [ HtmlA.class "dangerous" ]
                    [ Button.view
                        Button.Raised
                        Button.Padded
                        "Go Bankrupt"
                        (Icon.recycle |> Icon.view |> Just)
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
                (Icon.times |> Icon.view |> Just)
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
        , expect =
            Http.expectJson (LoadBets id >> wrap)
                (JsonD.assocListFromList (JsonD.field "id" Game.idDecoder)
                    (JsonD.field "game" Game.withBetsDecoder)
                )
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
