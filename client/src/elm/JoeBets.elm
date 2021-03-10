module JoeBets exposing (main)

import Browser
import Browser.Events as Browser
import Browser.Navigation as Navigation
import FontAwesome.Brands as Icon
import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html
import Html.Attributes as HtmlA
import JoeBets.Page.About as About
import JoeBets.Page.Bet as Bet
import JoeBets.Page.Bet.Model as Bet
import JoeBets.Page.Bets as Bets
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Page.Edit as Edit
import JoeBets.Page.Edit.Model as Edit
import JoeBets.Page.Edit.Msg as Edit
import JoeBets.Page.Games as Games
import JoeBets.Page.Games.Model as Games
import JoeBets.Page.Leaderboard as Leaderboard
import JoeBets.Page.Leaderboard.Model as Leaderboard
import JoeBets.Page.Model as Page exposing (Page)
import JoeBets.Page.Unknown as Unknown
import JoeBets.Page.Unknown.Model as Unknown
import JoeBets.Page.User as User
import JoeBets.Page.User.Model as User
import JoeBets.Route as Route exposing (Route)
import JoeBets.User as User
import JoeBets.User.Auth as Auth
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Notifications as Notifications
import Task
import Time
import Url exposing (Url)
import Util.Html as Html
import Util.Maybe as Maybe


type alias Flags =
    {}


type alias Model =
    { origin : String
    , navigationKey : Navigation.Key
    , zone : Time.Zone
    , time : Time.Posix
    , page : Page
    , auth : Auth.Model
    , notifications : Notifications.Model
    , user : User.Model
    , bets : Bets.Model
    , bet : Bet.Model
    , games : Games.Model
    , leaderboard : Leaderboard.Model
    , edit : Edit.Model
    , unknown : Unknown.Model
    , visibility : Browser.Visibility
    }


type Msg
    = ChangeUrl Route
    | UrlChanged Route
    | SetTimeZone Time.Zone
    | SetTime Time.Posix
    | AuthMsg Auth.Msg
    | NotificationsMsg Notifications.Msg
    | UserMsg User.Msg
    | BetsMsg Bets.Msg
    | BetMsg Bet.Msg
    | GamesMsg Games.Msg
    | LeaderboardMsg Leaderboard.Msg
    | EditMsg Edit.Msg
    | ChangeVisibility Browser.Visibility
    | NoOp


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

        initModel =
            { origin = origin
            , navigationKey = key
            , zone = Time.utc
            , time = Time.millisToPosix 0
            , page = Page.About
            , auth = auth
            , notifications = Notifications.init
            , user = User.init
            , bets = Bets.init
            , bet = Bet.init
            , games = Games.init
            , leaderboard = Leaderboard.init
            , edit = Edit.init
            , unknown = Unknown.init
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
            ( { model | time = now }, Cmd.none )

        SetTimeZone zone ->
            ( { model | zone = zone }, Cmd.none )

        AuthMsg authMsg ->
            Auth.update AuthMsg NoOp NotificationsMsg authMsg model

        NotificationsMsg notificationsMsg ->
            Notifications.update NotificationsMsg notificationsMsg model

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

        ChangeVisibility visibility ->
            ( { model | visibility = visibility }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Time.every 10000 SetTime
        , Browser.onVisibilityChange ChangeVisibility
        , Notifications.subscriptions NotificationsMsg model
        ]


view : Model -> Browser.Document Msg
view model =
    let
        { title, id, body } =
            case model.page of
                Page.About ->
                    About.view

                Page.User ->
                    User.view UserMsg model

                Page.Bet ->
                    Bet.view BetMsg model

                Page.Bets ->
                    Bets.view BetsMsg model

                Page.Games ->
                    Games.view GamesMsg model

                Page.Leaderboard ->
                    Leaderboard.view LeaderboardMsg model

                Page.Edit ->
                    Edit.view EditMsg model

                Page.Unknown ->
                    Unknown.view model

        menu =
            [ [ Html.li [] [ Route.a Route.About [] [ Icon.questionCircle |> Icon.viewIcon, Html.text "About" ] ]
              , Html.li [] [ Route.a Route.Games [] [ Icon.dice |> Icon.viewIcon, Html.text "Bets" ] ]
              , Html.li [] [ Route.a Route.Leaderboard [] [ Icon.crown |> Icon.viewIcon, Html.text "Leaderboard" ] ]
              ]
            , model.auth.localUser |> Maybe.map (User.link >> List.singleton >> Html.li [ HtmlA.class "me" ]) |> Maybe.toList
            , [ Html.li [ HtmlA.class "discord" ] [ Auth.logInOutButton AuthMsg model ]
              , Html.li [ HtmlA.class "stream" ]
                    [ Html.blankA "https://www.twitch.tv"
                        [ "andersonjph" ]
                        [ Icon.twitch |> Icon.viewIcon, Html.text "The Stream" ]
                    ]
              ]
            ]
    in
    { title = "JASB - " ++ title
    , body =
        [ Html.header []
            [ Html.h1 [] [ Html.text "Joseph Anderson Stream Bets" ]
            , Html.nav [] [ menu |> List.concat |> Html.ul [] ]
            ]
        , Html.div [ HtmlA.class "page", HtmlA.id id ] body
        , Notifications.view NotificationsMsg model
        ]
    }


load : Route -> Model -> ( Model, Cmd Msg )
load route model =
    case route of
        Route.About ->
            ( { model | page = Page.About }, Cmd.none )

        Route.Auth maybeCodeAndState ->
            Auth.load AuthMsg maybeCodeAndState model

        Route.User maybeId ->
            User.load UserMsg maybeId { model | page = Page.User }

        Route.Bets id filters ->
            Bets.load BetsMsg id filters { model | page = Page.Bets }

        Route.Bet gameId betId ->
            Bet.load BetMsg gameId betId { model | page = Page.Bet }

        Route.Games ->
            Games.load GamesMsg { model | page = Page.Games }

        Route.Leaderboard ->
            Leaderboard.load LeaderboardMsg { model | page = Page.Leaderboard }

        Route.Edit target ->
            Edit.load EditMsg target { model | page = Page.Edit }

        Route.UnknownPage path ->
            Unknown.load path { model | page = Page.Unknown }
