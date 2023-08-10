module JoeBets.Page.User exposing
    ( init
    , load
    , update
    , view
    )

import AssocList
import Browser.Navigation as Browser
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Api as Api
import JoeBets.Api.Action as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.IdData as Api
import JoeBets.Api.Path as Api
import JoeBets.Bet as Bet
import JoeBets.Bet.Editor.LockMoment as LockMoment
import JoeBets.Coins as Coins
import JoeBets.Error as Error
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game
import JoeBets.Messages as Global
import JoeBets.Overlay as Overlay
import JoeBets.Page exposing (Page)
import JoeBets.Page.Gacha.Collection.Route as Collection
import JoeBets.Page.Gacha.Route as Route
import JoeBets.Page.User.Model exposing (..)
import JoeBets.Route as Route
import JoeBets.User as User
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Model as User
import Json.Encode as JsonE
import Material.Button as Button
import Material.Switch as Switch
import Time.Model as Time
import Util.Html as Html
import Util.Html.Events as HtmlE
import Util.Json.Decode as JsonD
import Util.Maybe as Maybe


wrap : Msg -> Global.Msg
wrap =
    Global.UserMsg


type alias Parent a =
    { a
        | user : Model
        , auth : Auth.Model
        , navigationKey : Browser.Key
        , origin : String
        , time : Time.Context
    }


init : Model
init =
    { user = Api.initIdData
    , bets = Api.initIdData
    , bankruptcyOverlay = Nothing
    , permissionsOverlay = Nothing
    }


load : Maybe User.Id -> Parent a -> ( Parent a, Cmd Global.Msg )
load requestedUserId ({ auth, user } as model) =
    case requestedUserId of
        Just userId ->
            let
                ( userData, loadUser ) =
                    { path = Api.SpecificUser userId Api.User
                    , wrap = Load userId >> wrap
                    , decoder = User.withIdDecoder
                    }
                        |> Api.get model.origin
                        |> Api.getIdData userId user.user

                newUser =
                    { user
                        | user = userData
                        , bankruptcyOverlay = Nothing
                        , permissionsOverlay = Nothing
                    }
            in
            ( { model | user = newUser }, Cmd.batch [ loadUser ] )

        Nothing ->
            case auth.localUser |> Maybe.map .id of
                Just userId ->
                    ( model
                    , userId
                        |> Just
                        |> Route.User
                        |> Route.pushUrl model.navigationKey
                    )

                Nothing ->
                    ( { model | user = { user | user = Api.initIdData } }
                    , Cmd.none
                    )


update : Msg -> Parent a -> ( Parent a, Cmd Global.Msg )
update msg ({ user, auth, origin } as model) =
    case msg of
        Load id result ->
            let
                newAuth =
                    case result of
                        Ok userData ->
                            if Just id == (auth.localUser |> Maybe.map .id) then
                                { auth | localUser = Just userData }

                            else
                                auth

                        Err _ ->
                            auth

                u =
                    result |> Result.map .user
            in
            ( { model
                | user = { user | user = user.user |> Api.updateIdData id u }
                , auth = newAuth
              }
            , Cmd.none
            )

        TryLoadBets userId ->
            let
                ( bets, cmd ) =
                    if Api.toMaybeId user.user == Just userId then
                        { path = Api.SpecificUser userId Api.UserBets
                        , wrap = LoadBets userId >> wrap
                        , decoder =
                            JsonD.assocListFromTupleList Game.idDecoder Game.withBetsDecoder
                        }
                            |> Api.get origin
                            |> Api.getIdDataIfMissing userId user.bets

                    else
                        ( user.bets, Cmd.none )
            in
            ( { model | user = { user | bets = bets } }, cmd )

        LoadBets userId result ->
            let
                bets =
                    user.bets |> Api.updateIdData userId result
            in
            ( { model | user = { user | bets = bets } }, Cmd.none )

        SetBankruptcyToggle enabled ->
            let
                updateUser givenUser =
                    { givenUser | bankruptcyOverlay = givenUser.bankruptcyOverlay |> Maybe.map updateOverlay }

                updateOverlay overlay =
                    { overlay | sureToggle = enabled }
            in
            ( { model | user = user |> updateUser }, Cmd.none )

        GoBankrupt uid maybeResult ->
            case user.bankruptcyOverlay of
                Just overlay ->
                    case maybeResult of
                        Nothing ->
                            let
                                ( newOverlayAction, cmd ) =
                                    { path = Api.SpecificUser uid Api.Bankrupt
                                    , body = JsonE.null
                                    , wrap = Just >> GoBankrupt uid >> wrap
                                    , decoder = User.withIdDecoder
                                    }
                                        |> Api.post model.origin
                                        |> Api.doAction overlay.action
                            in
                            ( { model
                                | user =
                                    { user
                                        | bankruptcyOverlay =
                                            Just { overlay | action = newOverlayAction }
                                    }
                              }
                            , cmd
                            )

                        Just result ->
                            let
                                ( updatedUser, state ) =
                                    overlay.action |> Api.handleActionResult result

                                ( changeUser, newOverlay ) =
                                    case updatedUser of
                                        Just userWithId ->
                                            ( Api.updateIdDataValue uid (\_ -> userWithId.user)
                                            , Nothing
                                            )

                                        Nothing ->
                                            ( identity, Just { overlay | action = state } )
                            in
                            ( { model
                                | user =
                                    { user
                                        | user = user.user |> changeUser
                                        , bankruptcyOverlay = newOverlay
                                    }
                              }
                            , Cmd.none
                            )

                Nothing ->
                    ( model, Cmd.none )

        ToggleBankruptcyOverlay id show ->
            if Just id == Api.toMaybeId user.user then
                let
                    ( bankruptcyOverlay, cmd ) =
                        if show then
                            let
                                ( stats, loadStatsCmd ) =
                                    { path = Api.SpecificUser id Api.Bankrupt
                                    , wrap = LoadBankruptcyStats id >> wrap
                                    , decoder = bankruptcyStatsDecoder
                                    }
                                        |> Api.get model.origin
                                        |> Api.initGetData
                            in
                            ( Just
                                { sureToggle = False
                                , stats = stats
                                , action = Api.initAction
                                }
                            , loadStatsCmd
                            )

                        else
                            ( Nothing, Cmd.none )
                in
                ( { model | user = { user | bankruptcyOverlay = bankruptcyOverlay } }
                , cmd
                )

            else
                ( model, Cmd.none )

        LoadBankruptcyStats id result ->
            if Just id == Api.toMaybeId user.user then
                let
                    updateOverlay overlay =
                        { overlay | stats = overlay.stats |> Api.updateData result }

                    newOverlay =
                        user.bankruptcyOverlay |> Maybe.map updateOverlay
                in
                ( { model | user = { user | bankruptcyOverlay = newOverlay } }
                , Cmd.none
                )

            else
                ( model, Cmd.none )

        TogglePermissionsOverlay id show ->
            if Just id == Api.toMaybeId user.user then
                let
                    ( permissionsOverlay, cmd ) =
                        if show then
                            let
                                ( permissions, loadPermissionsCmd ) =
                                    { path = Api.SpecificUser id Api.Permissions
                                    , wrap = LoadPermissions id >> wrap
                                    , decoder = editablePermissionsDecoder
                                    }
                                        |> Api.get model.origin
                                        |> Api.initGetData
                            in
                            ( Just { permissions = permissions }
                            , loadPermissionsCmd
                            )

                        else
                            ( Nothing, Cmd.none )
                in
                ( { model | user = { user | permissionsOverlay = permissionsOverlay } }
                , cmd
                )

            else
                ( model, Cmd.none )

        LoadPermissions userId response ->
            if Just userId == Api.toMaybeId user.user then
                let
                    updatePermissions overlay =
                        { overlay | permissions = overlay.permissions |> Api.updateData response }

                    newOverlay =
                        user.permissionsOverlay |> Maybe.map updatePermissions
                in
                ( { model | user = { user | permissionsOverlay = newOverlay } }
                , Cmd.none
                )

            else
                ( model, Cmd.none )

        SetPermissions userId permission ->
            if Just userId == Api.toMaybeId user.user then
                ( model
                  -- TODO: NoOping this result is wrong.
                , { path = Api.SpecificUser userId Api.Permissions
                  , body = permission |> encodeSetPermissions
                  , wrap = \_ -> "Set permissions result." |> NoOp |> wrap
                  , decoder = editablePermissionsDecoder
                  }
                    |> Api.post origin
                )

            else
                ( model, Cmd.none )

        NoOp _ ->
            ( model, Cmd.none )


view : Parent a -> Page Global.Msg
view model =
    let
        { bets, bankruptcyOverlay, permissionsOverlay } =
            model.user
    in
    case model.user.user |> Api.idDataToData of
        Just ( id, user ) ->
            let
                isLocal =
                    Just id == (model.auth.localUser |> Maybe.map .id)

                htmlTitle =
                    case user |> Api.dataToMaybe of
                        Just u ->
                            [ Html.text "“"
                            , User.viewName u
                            , Html.text "” ("
                            , Html.text (User.idToString id)
                            , Html.text ")"
                            ]

                        Nothing ->
                            [ Html.text (User.idToString id) ]

                title =
                    case user |> Api.dataToMaybe of
                        Just u ->
                            "“" ++ User.nameString u ++ "” (" ++ User.idToString id ++ ")"

                        Nothing ->
                            User.idToString id

                body userData =
                    let
                        avatar =
                            User.viewAvatar userData

                        adminControls =
                            if Auth.canManagePermissions model.auth.localUser then
                                [ [ Html.div [ HtmlA.class "manage-user" ]
                                        [ Button.filled "Edit Permissions"
                                            |> Button.button (TogglePermissionsOverlay id True |> wrap |> Just)
                                            |> Button.icon (Icon.userCog |> Icon.view)
                                            |> Button.view
                                        ]
                                  ]
                                , permissionsOverlay |> Maybe.map (viewPermissionsOverlay id) |> Maybe.withDefault []
                                ]
                                    |> List.concat

                            else
                                []

                        bankruptcyControls =
                            if isLocal then
                                [ [ Html.div [ HtmlA.class "bankrupt dangerous" ]
                                        [ Html.h3 [] [ Html.text "Bankruptcy" ]
                                        , Html.p []
                                            [ Html.text "Going bankrupt will reset your balance to the "
                                            , Html.text "starting amount, and cancel all your current bets. "
                                            , Html.text "Your cards will not be affected."
                                            ]
                                        , Button.filled "Go Bankrupt"
                                            |> Button.button (ToggleBankruptcyOverlay id True |> wrap |> Just)
                                            |> Button.icon (Icon.recycle |> Icon.view)
                                            |> Button.view
                                        ]
                                  ]
                                , bankruptcyOverlay |> Maybe.map (viewBankruptcyOverlay id) |> Maybe.withDefault []
                                ]
                                    |> List.concat

                            else
                                []

                        controls =
                            List.concat [ bankruptcyControls, adminControls ]

                        netWorthEntry ( prefix, name, amount ) =
                            Html.li []
                                [ Html.span [] [ Html.text prefix ]
                                , Html.span [ HtmlA.class "title" ] [ Html.text name ]
                                , Coins.view amount
                                ]

                        netWorth =
                            [ ( "", "Net Worth", userData.balance + userData.betValue )
                            , ( "=", "Balance", userData.balance )
                            , ( "+", "Bets", userData.betValue )
                            ]

                        localCardsSection =
                            if isLocal then
                                [ Html.li []
                                    [ Route.a (Route.Forge |> Route.Gacha)
                                        []
                                        [ Icon.hammer |> Icon.view
                                        , Html.text "Forge Cards Of Yourself"
                                        ]
                                    ]
                                ]

                            else
                                []

                        cardsSection =
                            [ Html.li []
                                [ Route.a (Collection.Overview |> Route.CardCollection id)
                                    []
                                    [ Icon.layerGroup |> Icon.view
                                    , Html.text "Card Collection"
                                    ]
                                ]
                                :: localCardsSection
                                |> Html.ul [ HtmlA.class "gacha-links" ]
                            ]

                        betsSection =
                            [ Html.details [ HtmlA.class "bets", (\_ -> TryLoadBets id |> wrap) |> HtmlE.onToggle ]
                                [ Html.summary []
                                    [ Html.h3 [] [ Html.text "Bets Placed By This User" ]
                                    , Html.summaryMarker
                                    ]
                                , bets
                                    |> Api.viewSpecificIdData Api.viewOrNothing (viewBets model.time model.auth) id
                                    |> Html.div []
                                ]
                            ]

                        contents =
                            [ [ Html.h2 [ HtmlA.class "user" ]
                                    [ avatar, Html.span [] htmlTitle ]
                              , netWorth
                                    |> List.map netWorthEntry
                                    |> Html.ul [ HtmlA.class "net-worth" ]
                              ]
                            , cardsSection
                            , betsSection
                            , controls
                            ]
                    in
                    contents |> List.concat
            in
            { title = "User " ++ title
            , id = "user"
            , body = user |> Api.viewData Api.viewOrError body
            }

        Nothing ->
            { title = "User Profile"
            , id = "user"
            , body =
                [ Error.view
                    { reason = Error.UserMistake
                    , message = "You must be logged in to view your profile."
                    }
                ]
            }


viewBets : Time.Context -> Auth.Model -> User.Id -> AssocList.Dict Game.Id Game.WithBets -> List (Html Global.Msg)
viewBets time auth targetUserId =
    let
        viewBet gameId game ( id, bet ) =
            Html.li []
                [ Bet.viewSummarised
                    Global.ChangeUrl
                    time
                    (Bet.readOnlyFromAuth auth)
                    (Just targetUserId)
                    gameId
                    game.name
                    id
                    bet
                ]

        viewLockMomentBets gameId game ( id, ( lockMoment, bets ) ) =
            [ Html.div [ HtmlA.class "lock-moment" ]
                [ Html.text lockMoment ]
            , bets
                |> AssocList.toList
                |> List.map (viewBet gameId game)
                |> Html.ol [ HtmlA.class "bets-section" ]
            ]
                |> Html.li [ id |> LockMoment.idToString |> HtmlA.id ]

        viewGame ( id, { game, bets } ) =
            Html.li []
                [ Html.details []
                    [ Html.summary [] [ Html.h4 [] [ Html.text game.name ], Html.summaryMarker ]
                    , bets
                        |> AssocList.toList
                        |> List.map (viewLockMomentBets id game)
                        |> Html.ol [ HtmlA.class "lock-moments" ]
                    ]
                ]
    in
    AssocList.toList >> List.map viewGame >> Html.ul [ HtmlA.class "game-section" ] >> List.singleton


viewBankruptcyOverlay : User.Id -> BankruptcyOverlay -> List (Html Global.Msg)
viewBankruptcyOverlay userId { sureToggle, stats } =
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
            stats |> Api.viewData Api.viewOrError viewStats

        controls =
            [ Html.label [ HtmlA.class "dangerous", HtmlA.class "switch" ]
                [ Html.span [] [ Html.text "I am sure I want to do this." ]
                , Switch.switch
                    (SetBankruptcyToggle >> wrap |> Just)
                    sureToggle
                    |> Switch.view
                ]
            , Html.div [ HtmlA.class "actions" ]
                [ Button.text "Cancel"
                    |> Button.button (ToggleBankruptcyOverlay userId False |> wrap |> Just)
                    |> Button.icon (Icon.times |> Icon.view)
                    |> Button.view
                , Html.div [ HtmlA.class "dangerous" ]
                    [ Button.filled "Go Bankrupt"
                        |> Button.button (GoBankrupt userId Nothing |> wrap |> Maybe.when sureToggle)
                        |> Button.icon (Icon.recycle |> Icon.view)
                        |> Button.view
                    ]
                ]
            ]
    in
    [ Overlay.view (False |> ToggleBankruptcyOverlay userId |> wrap)
        [ [ renderedStats, controls ]
            |> List.concat
            |> Html.div [ HtmlA.id "bankruptcy-overlay" ]
        ]
    ]


viewPermissionsOverlay : User.Id -> PermissionsOverlay -> List (Html Global.Msg)
viewPermissionsOverlay userId overlay =
    let
        setPerms perm v =
            SetPermissions userId (perm v) |> wrap

        body { manageBets, manageGames, managePermissions, manageGacha, gameSpecific } =
            [ Html.label [ HtmlA.class "switch" ]
                [ Html.span [] [ Html.text "Manage Games" ]
                , Switch.switch (setPerms ManageGames |> Just) manageGames
                    |> Switch.view
                ]
            , Html.label [ HtmlA.class "switch" ]
                [ Html.span [] [ Html.text "Manage Permissions" ]
                , Switch.switch (setPerms ManagePermissions |> Just) managePermissions
                    |> Switch.view
                ]
            , Html.label [ HtmlA.class "switch" ]
                [ Html.span [] [ Html.text "Manage Gacha" ]
                , Switch.switch (setPerms ManageGacha |> Just) manageGacha
                    |> Switch.view
                ]
            , Html.label [ HtmlA.class "switch" ]
                [ Html.span [] [ Html.text "Manage All Bets" ]
                , Switch.switch (setPerms (ManageBets Nothing) |> Just) manageBets
                    |> Switch.view
                ]
            , gameSpecific |> AssocList.values |> List.map viewGamePermissions |> Html.ul []
            ]

        viewGamePermissions { gameId, gameName, permissions } =
            Html.li []
                [ Html.span [] [ Html.text gameName ]
                , Html.label [ HtmlA.class "switch" ]
                    [ Html.span [] [ Html.text "Manage" ]
                    , Switch.switch
                        (setPerms (ManageBets (Just gameId)) |> Just)
                        permissions.manageBets
                        |> Switch.view
                    ]
                ]

        alwaysBody =
            [ Button.text "Close"
                |> Button.button (TogglePermissionsOverlay userId False |> wrap |> Just)
                |> Button.icon (Icon.times |> Icon.view)
                |> Button.view
            ]
    in
    [ Overlay.view (TogglePermissionsOverlay userId False |> wrap)
        [ [ overlay.permissions |> Api.viewData Api.viewOrError body, alwaysBody ]
            |> List.concat
            |> Html.div [ HtmlA.id "permissions-overlay" ]
        ]
    ]
