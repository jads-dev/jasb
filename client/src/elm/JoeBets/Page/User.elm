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
import JoeBets.Page exposing (Page)
import JoeBets.Page.Gacha.Collection.Route as Collection
import JoeBets.Page.Gacha.Route as Route
import JoeBets.Page.User.Model exposing (..)
import JoeBets.Route as Route
import JoeBets.User as User
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Model as User
import JoeBets.User.Permission as Permission
import JoeBets.User.Permission.Selector as Permission
import Json.Encode as JsonE
import Material.Button as Button
import Material.Dialog as Dialog
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
    , bankruptcyDialog = initBankruptcyDialog
    , permissionsDialog = initPermissionsDialog
    }


closeDialog : { dialog | open : Bool } -> { dialog | open : Bool }
closeDialog dialog =
    { dialog | open = False }


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
                        , bankruptcyDialog = initBankruptcyDialog
                        , permissionsDialog = initPermissionsDialog
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
                updateDialog dialog =
                    { dialog | sureToggle = enabled }

                updateUser givenUser =
                    { givenUser | bankruptcyDialog = updateDialog givenUser.bankruptcyDialog }
            in
            ( { model | user = user |> updateUser }, Cmd.none )

        GoBankrupt uid maybeResult ->
            case maybeResult of
                Nothing ->
                    let
                        dialog =
                            user.bankruptcyDialog

                        ( newAction, cmd ) =
                            { path = Api.SpecificUser uid Api.Bankrupt
                            , body = JsonE.null
                            , wrap = Just >> GoBankrupt uid >> wrap
                            , decoder = User.withIdDecoder
                            }
                                |> Api.post model.origin
                                |> Api.doAction dialog.action
                    in
                    ( { model | user = { user | bankruptcyDialog = { dialog | action = newAction } } }
                    , cmd
                    )

                Just result ->
                    let
                        dialog =
                            user.bankruptcyDialog

                        ( updatedUser, state ) =
                            dialog.action |> Api.handleActionResult result

                        ( changeUser, newDialog ) =
                            case updatedUser of
                                Just userWithId ->
                                    ( Api.updateIdDataValue uid (\_ -> userWithId.user)
                                    , { dialog | open = False }
                                    )

                                Nothing ->
                                    ( identity, { dialog | action = state } )
                    in
                    ( { model
                        | user =
                            { user
                                | user = user.user |> changeUser
                                , bankruptcyDialog = newDialog
                            }
                      }
                    , Cmd.none
                    )

        ToggleBankruptcyDialog id show ->
            if Just id == Api.toMaybeId user.user then
                let
                    ( bankruptcyDialog, cmd ) =
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
                            ( { initBankruptcyDialog | stats = stats, open = True }
                            , loadStatsCmd
                            )

                        else
                            ( closeDialog user.bankruptcyDialog, Cmd.none )
                in
                ( { model | user = { user | bankruptcyDialog = bankruptcyDialog } }
                , cmd
                )

            else
                ( model, Cmd.none )

        LoadBankruptcyStats id result ->
            if Just id == Api.toMaybeId user.user then
                let
                    updateDialog dialog =
                        { dialog | stats = dialog.stats |> Api.updateData result }

                    newDialog =
                        user.bankruptcyDialog |> updateDialog
                in
                ( { model | user = { user | bankruptcyDialog = newDialog } }
                , Cmd.none
                )

            else
                ( model, Cmd.none )

        TogglePermissionsDialog id show ->
            if Just id == Api.toMaybeId user.user then
                let
                    permissionsDialog =
                        if show then
                            { initPermissionsDialog | open = True }

                        else
                            closeDialog user.permissionsDialog
                in
                ( { model | user = { user | permissionsDialog = permissionsDialog } }
                , Cmd.none
                )

            else
                ( model, Cmd.none )

        LoadPermissions userId response ->
            if Just userId == Api.toMaybeId user.user then
                let
                    updatePermissions permissions u =
                        { u | permissions = permissions }

                    userData =
                        user.user |> Api.updateIdDataWith userId response updatePermissions
                in
                ( { model | user = { user | user = userData } }
                , Cmd.none
                )

            else
                ( model, Cmd.none )

        SetPermissions userId permission set ->
            if Just userId == Api.toMaybeId user.user then
                let
                    updateSelector dialog =
                        { dialog | selector = Permission.clear dialog.selector }
                in
                ( { model | user = { user | permissionsDialog = user.permissionsDialog |> updateSelector } }
                , { path = Api.SpecificUser userId Api.Permissions
                  , body = Permission.encodeSetPermission permission set
                  , wrap = LoadPermissions userId >> wrap
                  , decoder = Permission.permissionsDecoder
                  }
                    |> Api.post origin
                )

            else
                ( model, Cmd.none )

        SelectPermission userId permissionSelectorMsg ->
            if Just userId == Api.toMaybeId user.user then
                let
                    updateSelector dialog =
                        let
                            ( selector, cmd ) =
                                Permission.updateSelector
                                    (SelectPermission userId >> wrap)
                                    model
                                    permissionSelectorMsg
                                    dialog.selector
                        in
                        ( { dialog | selector = selector }, cmd )

                    ( updatedDialog, selectorCmd ) =
                        user.permissionsDialog
                            |> updateSelector
                in
                ( { model | user = { user | permissionsDialog = updatedDialog } }
                , selectorCmd
                )

            else
                ( model, Cmd.none )


view : Maybe User.Id -> Parent a -> Page Global.Msg
view _ model =
    let
        { bets, bankruptcyDialog, permissionsDialog } =
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
                                [ Html.div [ HtmlA.class "manage-user" ]
                                    [ Button.filled "Edit Permissions"
                                        |> Button.button (TogglePermissionsDialog id True |> wrap |> Just)
                                        |> Button.icon [ Icon.userCog |> Icon.view ]
                                        |> Button.view
                                    ]
                                , viewPermissionsDialog id userData permissionsDialog
                                ]

                            else
                                []

                        bankruptcyControls =
                            if isLocal then
                                [ Html.div [ HtmlA.class "bankrupt dangerous" ]
                                    [ Html.h3 [] [ Html.text "Bankruptcy" ]
                                    , Html.p []
                                        [ Html.text "Going bankrupt will reset your balance to the "
                                        , Html.text "starting amount, and cancel all your current bets. "
                                        , Html.text "Your cards will not be affected."
                                        ]
                                    , Button.filled "Go Bankrupt"
                                        |> Button.button (ToggleBankruptcyDialog id True |> wrap |> Just)
                                        |> Button.icon [ Icon.recycle |> Icon.view ]
                                        |> Button.view
                                    ]
                                , bankruptcyDialog |> viewBankruptcyDialog id
                                ]

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


viewBankruptcyDialog : User.Id -> BankruptcyDialog -> Html Global.Msg
viewBankruptcyDialog userId { open, sureToggle, stats } =
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
            , Html.label [ HtmlA.class "dangerous", HtmlA.class "switch" ]
                [ Html.span [] [ Html.text "I am sure I want to do this." ]
                , Switch.switch
                    (SetBankruptcyToggle >> wrap |> Just)
                    sureToggle
                    |> Switch.view
                ]
            ]

        renderedStats =
            stats |> Api.viewData Api.viewOrError viewStats

        controls =
            [ Button.text "Cancel"
                |> Button.button (ToggleBankruptcyDialog userId False |> wrap |> Just)
                |> Button.icon [ Icon.times |> Icon.view ]
                |> Button.view
            , Html.div [ HtmlA.class "dangerous" ]
                [ Button.filled "Go Bankrupt"
                    |> Button.button (GoBankrupt userId Nothing |> wrap |> Maybe.when sureToggle)
                    |> Button.icon [ Icon.recycle |> Icon.view ]
                    |> Button.view
                ]
            ]
    in
    Dialog.dialog (False |> ToggleBankruptcyDialog userId |> wrap)
        renderedStats
        controls
        open
        |> Dialog.headline [ Html.text "Are you sure?" ]
        |> Dialog.alert
        |> Dialog.attrs [ HtmlA.id "bankruptcy-dialog" ]
        |> Dialog.view


viewPermissionsDialog : User.Id -> User.User -> PermissionsDialog -> Html Global.Msg
viewPermissionsDialog userId user { selector, open } =
    let
        permissions =
            user.permissions

        setPerm v perm =
            SetPermissions userId perm v |> wrap

        suggestions =
            [ Permission.ManagePermissions
            , Permission.ManageGames
            , Permission.ManageBets Permission.AllBets
            , Permission.ManageGacha
            ]
                |> List.filter (\p -> permissions |> List.member p |> not)
    in
    Dialog.dialog (False |> TogglePermissionsDialog userId |> wrap)
        [ Permission.selector
            (SelectPermission userId >> wrap)
            (setPerm True)
            "0"
            permissions
            selector
        , Permission.viewPermissions setPerm suggestions permissions
        ]
        [ Html.div [ HtmlA.class "spacer" ] []
        , Button.text "Close"
            |> Button.button (TogglePermissionsDialog userId False |> wrap |> Just)
            |> Button.icon [ Icon.times |> Icon.view ]
            |> Button.view
        ]
        open
        |> Dialog.headline [ Html.span [] [ Html.text "Edit ", User.viewName user, Html.text "'s Permissions" ] ]
        |> Dialog.attrs [ HtmlA.id "permissions-dialog" ]
        |> Dialog.view
