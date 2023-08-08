module JoeBets.Navigation exposing
    ( Model
    , init
    , update
    , view
    )

import FontAwesome as Icon
import FontAwesome.Attributes as Icon
import FontAwesome.Brands as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Events as HtmlE
import JoeBets.Messages as Global
import JoeBets.Navigation.Messages exposing (..)
import JoeBets.Page.Leaderboard as Leaderboard
import JoeBets.Page.Leaderboard.Model as Leaderboard
import JoeBets.Page.Leaderboard.Route as Leaderboard
import JoeBets.Route as Route
import JoeBets.Settings as Settings
import JoeBets.Settings.Model as Settings
import JoeBets.User as User
import JoeBets.User.Auth as Auth
import JoeBets.User.Auth.Model as Auth
import Material.IconButton as IconButton
import Material.ListView as ListView
import Material.Menu as Menu
import Url.Builder
import Util.Html as Html
import Util.Maybe as Maybe


type alias Parent a =
    { a
        | origin : String
        , auth : Auth.Model
        , settings : Settings.Model
        , navigation : Model
    }


type alias Model =
    { moreSubmenu : Menu.State
    , userSubmenu : Menu.State
    }


init : Model
init =
    { moreSubmenu = Menu.Closed, userSubmenu = Menu.Closed }


type alias SubmenuItem msg =
    { action : ListView.Action msg
    , icon : Html msg
    , content : Html msg
    }


viewSubmenuItem : SubmenuItem msg -> Html msg
viewSubmenuItem { action, icon, content } =
    ListView.viewItem action (Just icon) Nothing Nothing [ content ]


viewSubmenu : (Menu.State -> Msg) -> String -> Html Global.Msg -> Menu.State -> List (SubmenuItem Global.Msg) -> Html Global.Msg
viewSubmenu set title icon state items =
    let
        doSet =
            set >> Global.NavigationMsg
    in
    items
        |> List.map viewSubmenuItem
        |> Menu.view (Menu.Closed |> doSet)
            state
            Menu.BottomRight
            Menu.End
            (IconButton.view icon title (Menu.Open |> doSet |> Maybe.when (state == Menu.Closed)))


linkAction : msg -> Route.Route -> ListView.Action msg
linkAction close route =
    (List.singleton >> Route.a route [ HtmlE.onClick close ])
        |> ListView.Link


externalLinkAction : msg -> String -> List String -> ListView.Action msg
externalLinkAction close origin path =
    let
        blankA content =
            Html.a
                [ Url.Builder.crossOrigin origin path [] |> HtmlA.href
                , HtmlA.target "_blank"
                , HtmlA.rel "noopener"
                , HtmlE.onClick close
                ]
                [ content ]
    in
    blankA |> ListView.Link


viewUserSubmenu : Parent a -> ( Html Global.Msg, List (SubmenuItem Global.Msg) )
viewUserSubmenu model =
    case model.auth.localUser of
        Just localUser ->
            ( User.viewAvatar localUser.id localUser.user
            , [ { action =
                    linkAction
                        (Menu.Closed |> SetUserSubmenuState |> Global.NavigationMsg)
                        (localUser.id |> Just |> Route.User)
                , icon = Icon.user |> Icon.view
                , content = Html.text "Profile"
                }
              , { action =
                    Auth.Logout
                        |> Global.AuthMsg
                        |> Maybe.when (model.auth.inProgress == Nothing)
                        |> ListView.Button
                , icon = Icon.signOut |> Icon.view
                , content = Html.text "Log Out"
                }
              ]
            )

        Nothing ->
            ( Icon.user |> Icon.view
            , [ { action =
                    Auth.Start
                        |> Auth.Login
                        |> Global.AuthMsg
                        |> Maybe.when (model.auth.inProgress == Nothing)
                        |> ListView.Button
                , icon = Icon.signIn |> Icon.view
                , content = Html.text "Log In"
                }
              ]
            )


update : Msg -> Parent a -> ( Parent a, Cmd Global.Msg )
update msg parent =
    case msg of
        SetMoreSubmenuState newState ->
            let
                nav =
                    parent.navigation
            in
            ( { parent | navigation = { nav | moreSubmenu = newState } }
            , Cmd.none
            )

        SetUserSubmenuState newState ->
            let
                nav =
                    parent.navigation
            in
            ( { parent | navigation = { nav | userSubmenu = newState } }
            , Cmd.none
            )


view : Parent a -> Html Global.Msg
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
            viewSubmenu SetUserSubmenuState
                "User"
                userIcon
                model.navigation.userSubmenu
                userSubmenuItems

        external =
            Html.span [ HtmlA.class "external" ] [ Icon.externalLinkAlt |> Icon.view ]

        showSettings =
            True |> Settings.SetVisibility |> Global.SettingsMsg |> Just

        closeMore =
            Menu.Closed |> SetMoreSubmenuState |> Global.NavigationMsg

        moreSubmenu =
            viewSubmenu SetMoreSubmenuState
                "More"
                (Icon.ellipsisVertical |> Icon.view)
                model.navigation.moreSubmenu
                [ { action = ListView.Button showSettings
                  , icon = Icon.cog |> Icon.view
                  , content = Html.text "Settings"
                  }
                , { action =
                        linkAction closeMore
                            Route.About
                  , icon = Icon.questionCircle |> Icon.view
                  , content = Html.text "About"
                  }
                , { action =
                        externalLinkAction closeMore
                            "https://www.twitch.tv"
                            [ "andersonjph" ]
                  , icon = Icon.twitch |> Icon.view
                  , content = Html.span [] [ Html.text "The Stream", external ]
                  }
                , { action =
                        externalLinkAction closeMore
                            "https://discord.gg"
                            [ "tJjNP4QRvV" ]
                  , icon = Icon.discord |> Icon.view
                  , content = Html.span [] [ Html.text "Notifications", external ]
                  }
                ]

        menu =
            [ Html.li []
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
            , Html.li [ HtmlA.class "more submenu" ] [ moreSubmenu ]
            , Html.li [ HtmlA.class "user submenu" ] [ userSubmenu ]
            ]

        errors =
            Auth.viewError model
    in
    Html.nav [] (Html.ul [] menu :: errors)
