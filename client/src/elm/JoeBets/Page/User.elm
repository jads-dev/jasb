module JoeBets.Page.User exposing
    ( init
    , load
    , update
    , view
    )

import Browser.Navigation as Navigation
import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Http
import JoeBets.Api as Api
import JoeBets.Bet as Bets
import JoeBets.Coins as Coins
import JoeBets.Page exposing (Page)
import JoeBets.Page.User.Model exposing (BankruptcyOverlay, Model, Msg(..), decodeBankruptcyStats, decodeUserBet)
import JoeBets.Route as Route
import JoeBets.User as User
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Model as User
import Json.Decode as JsonD
import Material.Button as Button
import Material.Switch as Switch
import Time.Model as Time
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


view : (Msg -> msg) -> Parent a -> Page msg
view wrap model =
    let
        { id, user, bankruptcyOverlay } =
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

                controls =
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

                viewUserBet { gameId, gameName, betId, bet } =
                    Html.li [ HtmlA.class "hide-spoilers" ]
                        [ Bets.viewSummarised model.time Nothing id gameId gameName betId bet ]

                viewUserBets =
                    List.map viewUserBet >> Html.ul [ HtmlA.class "user-bets" ] >> List.singleton

                userBets =
                    model.user.bets |> RemoteData.view viewUserBets

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

                    --, [ Html.p [] [ Html.text "Bets this user has made. Their bet will be shown striped." ] ]
                    --, userBets
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
