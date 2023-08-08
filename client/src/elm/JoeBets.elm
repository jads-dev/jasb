module JoeBets exposing (main)

import Browser
import Browser.Events as Browser
import Browser.Navigation as Navigation
import Html
import Html.Attributes as HtmlA
import JoeBets.Layout as Layout
import JoeBets.Messages exposing (..)
import JoeBets.Model exposing (..)
import JoeBets.Navigation as Navigation
import JoeBets.Page.About as About
import JoeBets.Page.Bet as Bet
import JoeBets.Page.Bet.Model as Bet
import JoeBets.Page.Bets as Bets
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Page.Edit as Edit
import JoeBets.Page.Edit.Model as Edit
import JoeBets.Page.Edit.Msg as Edit
import JoeBets.Page.Feed as Feed
import JoeBets.Page.Feed.Model as Feed
import JoeBets.Page.Games as Games
import JoeBets.Page.Games.Model as Games
import JoeBets.Page.Leaderboard as Leaderboard
import JoeBets.Page.Leaderboard.Model as Leaderboard
import JoeBets.Page.Leaderboard.Route as Leaderboard
import JoeBets.Page.Model as Page
import JoeBets.Page.Problem as Problem
import JoeBets.Page.Problem.Model as Problem
import JoeBets.Page.User as User
import JoeBets.Page.User.Model as User
import JoeBets.Route as Route exposing (Route)
import JoeBets.Settings as Settings
import JoeBets.Settings.Model as Settings
import JoeBets.Store as Store
import JoeBets.Store.KeyedItem as Store
import JoeBets.Store.Session as SessionStore
import JoeBets.Store.Session.Model as SessionStore
import JoeBets.Theme as Theme
import JoeBets.User as User
import JoeBets.User.Auth as Auth
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Notifications as Notifications
import JoeBets.User.Notifications.Model as Notifications
import Task
import Time
import Time.Model as Time
import Url exposing (Url)
import Util.Html as Html


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , onUrlRequest = onUrlRequest
        , onUrlChange = onUrlChange
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


init : Flags -> Url -> Navigation.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        route =
            Route.fromUrl url

        origin =
            url.host

        ( auth, authCmd ) =
            Auth.init AuthMsg NoOp origin route

        store =
            flags.store |> Store.init

        initModel =
            { origin = origin
            , navigationKey = key
            , time = { zone = Time.utc, now = Time.millisToPosix 0 }
            , route = route
            , navigation = Navigation.init
            , page = Page.About
            , auth = auth
            , notifications = Notifications.init
            , feed = Feed.init
            , user = User.init
            , bets = Bets.init store
            , bet = Bet.init
            , games = Games.init
            , leaderboard = Leaderboard.init
            , edit = Edit.init
            , settings = Settings.init store
            , problem = Problem.init
            , visibility = Browser.Visible
            }

        ( model, loadCmd ) =
            load route initModel

        timeCmd =
            Cmd.batch
                [ Time.here |> Task.perform SetTimeZone
                , Time.now |> Task.perform SetTime
                ]
    in
    ( model, Cmd.batch [ loadCmd, authCmd, timeCmd ] )


onUrlRequest : Browser.UrlRequest -> Msg
onUrlRequest urlRequest =
    case urlRequest of
        Browser.Internal url ->
            url |> Route.fromUrl |> ChangeUrl

        Browser.External _ ->
            NoOp


onUrlChange : Url -> Msg
onUrlChange url =
    url |> Route.fromUrl |> UrlChanged


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ChangeUrl route ->
            ( model, route |> Route.toUrl |> Navigation.pushUrl model.navigationKey )

        UrlChanged route ->
            load route model

        SetTime now ->
            let
                time =
                    model.time
            in
            ( { model | time = { time | now = now } }, Cmd.none )

        SetTimeZone zone ->
            let
                time =
                    model.time
            in
            ( { model | time = { time | zone = zone } }, Cmd.none )

        AuthMsg authMsg ->
            Auth.update AuthMsg NoOp NotificationsMsg authMsg model

        NotificationsMsg notificationsMsg ->
            Notifications.update NotificationsMsg notificationsMsg model

        FeedMsg feedMsg ->
            Feed.update FeedMsg feedMsg model

        UserMsg userMsg ->
            User.update UserMsg userMsg model

        BetsMsg betsMsg ->
            Bets.update BetsMsg betsMsg model

        BetMsg betMsg ->
            Bet.update BetMsg betMsg model

        GamesMsg betsMsg ->
            Games.update betsMsg model

        LeaderboardMsg leaderboardMsg ->
            Leaderboard.update leaderboardMsg model

        EditMsg editMsg ->
            Edit.update EditMsg editMsg model

        SettingsMsg settingsMsg ->
            Settings.update settingsMsg model

        ChangeVisibility visibility ->
            ( { model | visibility = visibility }, Cmd.none )

        NavigationMsg navigationMsg ->
            Navigation.update navigationMsg model

        NoOp ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        storeFromResult result =
            case result of
                Ok keyedItem ->
                    case keyedItem of
                        Store.SettingsItem change ->
                            change |> Settings.ReceiveChange |> SettingsMsg

                        Store.BetsItem change ->
                            change |> Bets.ReceiveStoreChange |> BetsMsg

                Err _ ->
                    NoOp

        sessionStoreFromResult result =
            case result of
                Ok keyedValue ->
                    case keyedValue of
                        SessionStore.LoginRedirectValue value ->
                            value |> Auth.RedirectAfterLogin |> AuthMsg

                Err _ ->
                    NoOp
    in
    Sub.batch
        [ Time.every 10000 SetTime
        , Browser.onVisibilityChange ChangeVisibility
        , Notifications.subscriptions NotificationsMsg model
        , Store.changedValues storeFromResult
        , SessionStore.retrievedValues sessionStoreFromResult
        ]


view : Model -> Browser.Document Msg
view model =
    let
        { title, id, body } =
            case model.page of
                Page.About ->
                    About.view AuthMsg model

                Page.Feed ->
                    Feed.view FeedMsg False model

                Page.User ->
                    User.view UserMsg model

                Page.Bet ->
                    Bet.view BetMsg BetsMsg model

                Page.Bets ->
                    Bets.view BetsMsg model

                Page.Games ->
                    Games.view GamesMsg BetsMsg model

                Page.Leaderboard ->
                    Leaderboard.view LeaderboardMsg model

                Page.Edit ->
                    Edit.view EditMsg BetsMsg model

                Page.Problem ->
                    Problem.view model

        combinedBody =
            [ [ Html.header []
                    [ Html.div []
                        [ Html.h1 [ HtmlA.title "Joseph Anderson Stream Bets" ] [ Html.text "JASB" ]
                        , Navigation.view model
                        ]
                    ]
              , Html.div [ HtmlA.class "core" ]
                    [ Html.div [ HtmlA.class "page", HtmlA.id id ] body
                    ]
              , Notifications.view NotificationsMsg model
              ]
            , Settings.view SettingsMsg model
            ]
    in
    { title = "JASB - " ++ title
    , body =
        [ combinedBody
            |> List.concat
            |> Html.div
                [ HtmlA.id "jasb"
                , model.settings.theme.value |> Theme.toClass
                , model.settings.layout.value |> Layout.toClass
                ]
        ]
    }


load : Route -> Model -> ( Model, Cmd Msg )
load route oldRouteModel =
    let
        model =
            { oldRouteModel | route = route }
    in
    case route of
        Route.About ->
            ( { model | page = Page.About }, Cmd.none )

        Route.Feed ->
            Feed.load FeedMsg Nothing { model | page = Page.Feed }

        Route.Auth maybeCodeAndState ->
            Auth.load AuthMsg maybeCodeAndState model

        Route.User maybeId ->
            User.load UserMsg maybeId { model | page = Page.User }

        Route.Bets subset id ->
            Bets.load BetsMsg id subset { model | page = Page.Bets }

        Route.Bet gameId betId ->
            Bet.load BetMsg gameId betId { model | page = Page.Bet }

        Route.Games ->
            Games.load GamesMsg { model | page = Page.Games }

        Route.Leaderboard board ->
            Leaderboard.load LeaderboardMsg
                board
                { model | page = Page.Leaderboard }

        Route.Edit target ->
            Edit.load EditMsg target { model | page = Page.Edit }

        Route.Problem path ->
            Problem.load path { model | page = Page.Problem }
