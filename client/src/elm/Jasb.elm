module Jasb exposing (main)

import Browser
import Browser.Events as Browser
import Browser.Navigation as Browser
import Html
import Html.Attributes as HtmlA
import Jasb.Layout as Layout
import Jasb.Messages exposing (..)
import Jasb.Model exposing (..)
import Jasb.Navigation as Navigation
import Jasb.Page.About as About
import Jasb.Page.Bet as Bet
import Jasb.Page.Bets as Bets
import Jasb.Page.Bets.Model as Bets
import Jasb.Page.Edit as Edit
import Jasb.Page.Feed as Feed
import Jasb.Page.Gacha as Gacha
import Jasb.Page.Gacha.Collection as Collection
import Jasb.Page.Gacha.Forge as Forge
import Jasb.Page.Games as Games
import Jasb.Page.Leaderboard as Leaderboard
import Jasb.Page.Problem as Problem
import Jasb.Page.User as User
import Jasb.Route as Route exposing (Route)
import Jasb.Settings as Settings
import Jasb.Settings.Model as Settings
import Jasb.Store as Store
import Jasb.Store.KeyedItem as Store
import Jasb.Store.Session as SessionStore
import Jasb.Store.Session.Model as SessionStore
import Jasb.Theme as Theme
import Jasb.User.Auth as Auth
import Jasb.User.Auth.Model as Auth
import Jasb.User.Notifications as Notifications
import Json.Decode as JsonD
import Task
import Time
import Url exposing (Url)


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


init : Flags -> Url -> Browser.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        route =
            Route.fromUrl url

        ( auth, authCmd ) =
            Auth.init flags.base route

        store =
            flags.store |> Store.init

        initModel =
            { origin = flags.base
            , navigationKey = key
            , time = { zone = Time.utc, now = Time.millisToPosix 0 }
            , route = route
            , navigation = Navigation.init
            , auth = auth
            , notifications = Notifications.init
            , feed = Feed.init
            , user = User.init
            , bets = Bets.init store
            , bet = Bet.init
            , games = Games.init
            , leaderboard = Leaderboard.init
            , gacha = Gacha.init
            , forge = Forge.init
            , collection = Collection.init
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

        Browser.External url ->
            "External URL requested: " ++ url |> NoOp


onUrlChange : Url -> Msg
onUrlChange url =
    url |> Route.fromUrl |> UrlChanged


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ChangeUrl route ->
            ( model
            , route |> Route.toUrl |> Browser.pushUrl model.navigationKey
            )

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
            Auth.update authMsg model

        NotificationsMsg notificationsMsg ->
            Notifications.update notificationsMsg model

        FeedMsg feedMsg ->
            Feed.update feedMsg model

        UserMsg userMsg ->
            User.update userMsg model

        CollectionMsg collectionMsg ->
            Collection.update collectionMsg model

        BetsMsg betsMsg ->
            Bets.update betsMsg model

        BetMsg betMsg ->
            Bet.update betMsg model

        GamesMsg betsMsg ->
            Games.update betsMsg model

        LeaderboardMsg leaderboardMsg ->
            Leaderboard.update leaderboardMsg model

        GachaMsg gachaMsg ->
            Gacha.update gachaMsg model

        EditMsg editMsg ->
            Edit.update editMsg model

        SettingsMsg settingsMsg ->
            Settings.update settingsMsg model

        ChangeVisibility visibility ->
            ( { model | visibility = visibility }, Cmd.none )

        NavigationMsg navigationMsg ->
            Navigation.update navigationMsg model

        NoOp _ ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    let
        storeFromResult result =
            case result of
                Ok keyedItem ->
                    case keyedItem of
                        Store.SettingsItem change ->
                            change |> Settings.ReceiveChange |> SettingsMsg

                        Store.BetsItem change ->
                            change |> Bets.ReceiveStoreChange |> BetsMsg

                Err error ->
                    "Error with local storage: " ++ JsonD.errorToString error |> NoOp

        sessionStoreFromResult result =
            case result of
                Ok keyedValue ->
                    case keyedValue of
                        SessionStore.LoginRedirectValue value ->
                            value |> Auth.RedirectAfterLogin |> AuthMsg

                Err error ->
                    "Error with session storage: " ++ JsonD.errorToString error |> NoOp
    in
    Sub.batch
        [ Time.every 30000 SetTime
        , Browser.onVisibilityChange ChangeVisibility
        , Notifications.subscriptions
        , Store.changedValues storeFromResult
        , SessionStore.retrievedValues sessionStoreFromResult
        ]


view : Model -> Browser.Document Msg
view model =
    let
        pageView =
            case model.route of
                Route.About ->
                    About.view

                Route.Feed ->
                    Feed.view

                Route.Auth maybeCodeAndState ->
                    Auth.view maybeCodeAndState

                Route.User maybeUserId ->
                    User.view maybeUserId

                Route.CardCollection userId collectionRoute ->
                    Collection.view userId collectionRoute

                Route.Bet game bet ->
                    Bet.view game bet

                Route.Bets subset game lockMoment ->
                    Bets.view subset game lockMoment

                Route.Games ->
                    Games.view

                Route.Leaderboard board ->
                    Leaderboard.view board

                Route.Gacha gachaRoute ->
                    Gacha.view gachaRoute

                Route.Edit editTarget ->
                    Edit.view editTarget

                Route.Problem problem ->
                    Problem.view problem

        { title, id, body } =
            pageView model

        combinedBody =
            [ [ Html.header []
                    [ Route.a Route.About
                        []
                        [ Html.h1 [ HtmlA.title "Joseph Anderson Stream Bets" ] [ Html.text "JASB" ] ]
                        :: Navigation.view model
                        |> Html.div []
                    ]
              , Html.div [ HtmlA.class "core" ]
                    [ Html.div [ HtmlA.class "page", HtmlA.id id ] body
                    ]
              ]
            , Notifications.view model
            , Settings.view SettingsMsg model
            ]
    in
    { title = "JASB - " ++ title
    , body =
        [ Html.div
            [ HtmlA.id "settings-wrapper"
            , model.settings.theme.value |> Theme.toClass
            , model.settings.layout.value |> Layout.toClass
            ]
            [ combinedBody |> List.concat |> Html.div [ HtmlA.id "jasb" ] ]
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
            ( model, Cmd.none )

        Route.Feed ->
            Feed.load model

        Route.Auth maybeCodeAndState ->
            Auth.load maybeCodeAndState model

        Route.User maybeId ->
            User.load maybeId model

        Route.CardCollection id collectionRoute ->
            Collection.load id collectionRoute model

        Route.Bets subset id lockMoment ->
            Bets.load id subset lockMoment model

        Route.Bet gameId betId ->
            Bet.load gameId betId model

        Route.Games ->
            Games.load model

        Route.Leaderboard board ->
            Leaderboard.load board model

        Route.Gacha gacha ->
            Gacha.load gacha model

        Route.Edit target ->
            Edit.load target model

        Route.Problem path ->
            Problem.load path model
