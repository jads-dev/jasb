module JoeBets exposing (main)

import Browser
import Browser.Events as Browser
import Browser.Navigation as Browser
import Html
import Html.Attributes as HtmlA
import JoeBets.Layout as Layout
import JoeBets.Messages exposing (..)
import JoeBets.Model exposing (..)
import JoeBets.Navigation as Navigation
import JoeBets.Page.About as About
import JoeBets.Page.Bet as Bet
import JoeBets.Page.Bets as Bets
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Page.Edit as Edit
import JoeBets.Page.Feed as Feed
import JoeBets.Page.Gacha as Gacha
import JoeBets.Page.Gacha.Collection as Collection
import JoeBets.Page.Gacha.Forge as Forge
import JoeBets.Page.Games as Games
import JoeBets.Page.Leaderboard as Leaderboard
import JoeBets.Page.Model as Page
import JoeBets.Page.Problem as Problem
import JoeBets.Page.User as User
import JoeBets.Route as Route exposing (Route)
import JoeBets.Settings as Settings
import JoeBets.Settings.Model as Settings
import JoeBets.Store as Store
import JoeBets.Store.KeyedItem as Store
import JoeBets.Store.Session as SessionStore
import JoeBets.Store.Session.Model as SessionStore
import JoeBets.Theme as Theme
import JoeBets.User.Auth as Auth
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Notifications as Notifications
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
            , page = Page.About
            , auth = auth
            , notifications = Notifications.init
            , feed = Feed.init
            , user = User.init
            , bets = Bets.init store
            , bet = Bet.init
            , games = Games.init
            , leaderboard = Leaderboard.init
            , gacha = Gacha.init Nothing
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
        [ Time.every 10000 SetTime
        , Browser.onVisibilityChange ChangeVisibility
        , Notifications.subscriptions
        , Store.changedValues storeFromResult
        , SessionStore.retrievedValues sessionStoreFromResult
        ]


view : Model -> Browser.Document Msg
view model =
    let
        { title, id, body } =
            case model.page of
                Page.About ->
                    About.view model

                Page.Feed ->
                    Feed.view model

                Page.User ->
                    User.view model

                Page.Collection ->
                    Collection.view model

                Page.Bet ->
                    Bet.view model

                Page.Bets ->
                    Bets.view model

                Page.Games ->
                    Games.view model

                Page.Leaderboard ->
                    Leaderboard.view model

                Page.Gacha ->
                    Gacha.view model

                Page.Edit ->
                    Edit.view model

                Page.Problem ->
                    Problem.view model

        combinedBody =
            [ [ Html.header []
                    [ Html.h1 [ HtmlA.title "Joseph Anderson Stream Bets" ] [ Html.text "JASB" ]
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
            Feed.load { model | page = Page.Feed }

        Route.Auth maybeCodeAndState ->
            Auth.load maybeCodeAndState model

        Route.User maybeId ->
            User.load maybeId { model | page = Page.User }

        Route.CardCollection id collectionRoute ->
            Collection.load id collectionRoute { model | page = Page.Collection }

        Route.Bets subset id ->
            Bets.load id subset { model | page = Page.Bets }

        Route.Bet gameId betId ->
            Bet.load gameId betId { model | page = Page.Bet }

        Route.Games ->
            Games.load { model | page = Page.Games }

        Route.Leaderboard board ->
            Leaderboard.load board { model | page = Page.Leaderboard }

        Route.Gacha gacha ->
            Gacha.load gacha { model | page = Page.Gacha }

        Route.Edit target ->
            Edit.load target { model | page = Page.Edit }

        Route.Problem path ->
            Problem.load path { model | page = Page.Problem }
