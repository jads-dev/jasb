module JoeBets.Navigation exposing
    ( init
    , update
    , view
    )

import FontAwesome as Icon
import FontAwesome.Attributes as Icon
import FontAwesome.Brands as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Material as Material
import JoeBets.Messages as Global
import JoeBets.Navigation.Messages exposing (..)
import JoeBets.Navigation.Model exposing (..)
import JoeBets.Page.Gacha.Route as Gacha
import JoeBets.Page.Leaderboard.Route as Leaderboard
import JoeBets.Route as Route
import JoeBets.Settings.Model as Settings
import JoeBets.User as User
import JoeBets.User.Auth as Auth
import JoeBets.User.Auth.Model as Auth
import Material.IconButton as IconButton
import Material.Menu as Menu
import Util.Maybe as Maybe


type alias Parent a =
    { a
        | origin : String
        , auth : Auth.Model
        , settings : Settings.Model
        , navigation : Model
    }


init : Model
init =
    { openSubMenu = Nothing }


viewSubMenu : SubMenu -> String -> String -> Html Global.Msg -> Maybe SubMenu -> List (Menu.Item Global.Msg) -> List (Html Global.Msg)
viewSubMenu self id title icon openSubMenu items =
    let
        open =
            openSubMenu == Just self
    in
    [ items
        |> List.map Menu.itemToChild
        |> Menu.menu id open
        |> Menu.fixed
        |> Menu.anchorCorner Menu.End Menu.End
        |> Menu.menuCorner Menu.Start Menu.End
        |> Menu.onClosed (CloseSubMenu self |> Global.NavigationMsg)
        |> Menu.view
    , IconButton.icon icon title
        |> IconButton.button (OpenSubMenu self |> Global.NavigationMsg |> Maybe.whenNot open)
        |> IconButton.attrs [ HtmlA.id id ]
        |> IconButton.view
    ]


viewUserSubmenu : Parent a -> ( Html Global.Msg, List (Menu.Item Global.Msg) )
viewUserSubmenu model =
    case model.auth.localUser of
        Just localUser ->
            ( User.viewAvatar localUser.user
            , [ Menu.item [ Html.text "Profile" ]
                    |> Material.menuLink Global.ChangeUrl (localUser.id |> Just |> Route.User)
                    |> Menu.start [ Icon.view Icon.user ]
              , Menu.item [ Html.text "Log Out" ]
                    |> (Auth.Logout
                            |> Global.AuthMsg
                            |> Maybe.when (model.auth.inProgress == Nothing)
                            |> Menu.button
                       )
                    |> Menu.start [ Icon.view Icon.signOut ]
              ]
            )

        Nothing ->
            ( Icon.user |> Icon.view
            , [ Menu.item [ Html.text "Log In" ]
                    |> (Auth.Start
                            |> Auth.Login
                            |> Global.AuthMsg
                            |> Maybe.when (model.auth.inProgress == Nothing)
                            |> Menu.button
                       )
                    |> Menu.start [ Icon.view Icon.signIn ]
              ]
            )


update : Msg -> Parent a -> ( Parent a, Cmd Global.Msg )
update msg ({ navigation } as parent) =
    case msg of
        OpenSubMenu subMenu ->
            ( { parent | navigation = { navigation | openSubMenu = Just subMenu } }
            , Cmd.none
            )

        CloseSubMenu subMenu ->
            if navigation.openSubMenu == Just subMenu then
                ( { parent | navigation = { navigation | openSubMenu = Nothing } }
                , Cmd.none
                )

            else
                ( parent, Cmd.none )


view : Parent a -> List (Html Global.Msg)
view model =
    let
        ( userIconIfNotTrying, userSubmenuItems ) =
            viewUserSubmenu model

        userIcon =
            if model.auth.inProgress /= Nothing then
                Icon.spinner |> Icon.styled [ Icon.spinPulse ] |> Icon.view

            else
                userIconIfNotTrying

        userSubmenu =
            viewSubMenu
                UserSubMenu
                "user-submenu"
                "User"
                userIcon
                model.navigation.openSubMenu
                userSubmenuItems

        showSettings =
            True |> Settings.SetVisibility |> Global.SettingsMsg |> Just

        moreSubmenu =
            viewSubMenu
                MoreSubMenu
                "more-submenu"
                "More"
                (Icon.ellipsisVertical |> Icon.view)
                model.navigation.openSubMenu
                [ Menu.item [ Html.text "Settings" ]
                    |> Menu.button showSettings
                    |> Menu.start [ Icon.view Icon.cog ]
                , Menu.item [ Html.text "About" ]
                    |> Material.menuLink Global.ChangeUrl Route.About
                    |> Menu.start [ Icon.view Icon.questionCircle ]
                , Menu.item [ Html.text "The Stream" ]
                    |> Material.externalMenuLink
                        "https://www.twitch.tv"
                        [ "andersonjph" ]
                    |> Menu.start [ Icon.view Icon.twitch ]
                    |> Menu.supportingText [ Html.text "andersonjph on Twitch" ]
                , Menu.item [ Html.text "Notifications" ]
                    |> Material.externalMenuLink
                        "https://discord.gg"
                        [ "tJjNP4QRvV" ]
                    |> Menu.start [ Icon.view Icon.discord ]
                    |> Menu.supportingText [ Html.text "Join the JASB discord server for notifications about bets." ]
                ]

        cardsIfLoggedIn =
            case model.auth.localUser of
                Just _ ->
                    [ Html.li []
                        [ Route.a (Route.Gacha Gacha.Roll)
                            []
                            [ Icon.gift |> Icon.view, Html.text "Cards" ]
                        ]
                    ]

                Nothing ->
                    []

        menu =
            [ [ Html.li []
                    [ Route.a Route.Feed
                        []
                        [ Icon.stream |> Icon.view, Html.text "Feed" ]
                    ]
              , Html.li []
                    [ Route.a Route.Games
                        []
                        [ Icon.dice |> Icon.view, Html.text "Bets" ]
                    ]
              , Html.li []
                    [ Route.a (Route.Leaderboard Leaderboard.NetWorth)
                        []
                        [ Icon.crown |> Icon.view, Html.text "Leaderboard" ]
                    ]
              ]
            , cardsIfLoggedIn
            , [ Html.li [ HtmlA.class "user-submenu submenu" ] userSubmenu
              , Html.li [ HtmlA.class "more-submenu submenu" ] moreSubmenu
              ]
            ]
                |> List.concat

        errors =
            Auth.viewError model
    in
    Html.nav [] [ Html.ul [] menu ] :: errors
